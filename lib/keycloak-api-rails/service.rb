# frozen_string_literal: true

require 'base64'
module KeycloakApiRails
  class MissingPublicKeysError < StandardError; end

  class Service
    REALM_NAME = /\A(?!\.+\z)[A-Za-z0-9._~-]{1,128}\z/.freeze
    SUPPORTED_ALGORITHMS = %i[RS256 RS384 RS512 PS256 PS384 PS512 ES256 ES384 ES512].freeze

    def initialize(key_resolver)
      configuration                          = KeycloakApiRails.config
      @key_resolver                          = key_resolver
      @skip_paths                            = normalize_skip_paths(configuration.skip_paths, configuration.logger)
      @opt_in                                = configuration.opt_in
      @token_expiration_tolerance_in_seconds = configuration.token_expiration_tolerance_in_seconds
      @expected_audiences                    = Array(configuration.expected_audience).map(&:to_s)
      @expected_token_type                   = configuration.expected_token_type
      @verify_not_before                     = configuration.verify_not_before
      @allow_token_in_query_string           = configuration.allow_token_in_query_string
      @allowed_algorithms                    = Array(configuration.allowed_algorithms).map(&:to_sym)
    end

    def decode_and_verify(token)
      raise TokenError.no_token(token) if token.nil? || token.empty?
      
      parts = token.to_s.split('.')
      raise TokenError.invalid_format(token) if parts.length < 3

      realm_id = extract_realm_from_token(token)
      raise TokenError.invalid_realm(token) unless realm_allowed?(realm_id)
      
      public_keys = @key_resolver.find_public_keys(realm_id)
      
      if public_keys.nil?
        raise MissingPublicKeysError, "No Keycloak public key is available to verify the token" 
      end

      decoded_token = decode(token, public_keys)
      verify_claims!(token, decoded_token, realm_id)
      decoded_token
    end

    def extract_realm_from_token(token)
      payload_segment = token.split('.', 3)[1]
      return nil unless payload_segment

      decoded_payload = Base64.urlsafe_decode64(payload_segment)
      parsed_payload  = JSON.parse(decoded_payload)

      if parsed_payload.is_a?(Hash)
        iss = parsed_payload['iss']
        return nil unless iss.is_a?(String)
  
        realm_id = iss.split('/').last
        if realm_id&.match?(REALM_NAME)
          realm_id 
        else
          nil
        end
      else
        nil
      end
    rescue JSON::ParserError, ArgumentError
      nil
    end

    def realm_allowed?(realm_id)
      config_realm_id = KeycloakApiRails.config.realm_id
      return true if config_realm_id.nil?
      return false if realm_id.nil?

      if config_realm_id.respond_to?(:call)
        config_realm_id.call(realm_id)
      elsif config_realm_id.is_a?(Array)
        config_realm_id.include?(realm_id)
      else
        config_realm_id == realm_id
      end
    end

    def read_token(uri, headers)
      header_token = Helper.read_token_from_headers(headers)
      if !header_token.empty?
        header_token
      elsif @allow_token_in_query_string
        Helper.read_token_from_query_string(uri).to_s
      else
        ""
      end
    end

    def need_middleware_authentication?(method, path, headers)
      !is_preflight?(method, headers) && (!@opt_in && !should_skip?(method, path))
    end

    private

    def decode(token, public_keys)
      JSON::JWT.decode(token, public_keys, @allowed_algorithms)
    rescue JSON::JWT::VerificationFailed, JSON::JWK::Set::KidNotFound => e
      raise TokenError.verification_failed(token, e)
    rescue JSON::JWT::InvalidFormat => e
      raise TokenError.invalid_format(token, e)
    rescue StandardError => e
      raise TokenError.unknown(token, e)
    end

    # RFC 7519 requires 'exp' and 'nbf' to be NumericDates.
    def verify_claims!(token, decoded_token, realm_id)
      raise TokenError.missing_claim(token, "exp") unless decoded_token.key?("exp")
      raise TokenError.invalid_claim(token, "exp") unless decoded_token["exp"].is_a?(Numeric)
      raise TokenError.invalid_claim(token, "nbf") if not_before_is_invalid?(decoded_token)
      raise TokenError.expired(token)              if expired?(decoded_token)
      raise TokenError.not_yet_valid(token)        if not_yet_valid?(decoded_token)
      raise TokenError.invalid_audience(token)     unless audience_valid?(decoded_token)
      raise TokenError.invalid_token_type(token)   unless token_type_valid?(decoded_token)

      if KeycloakApiRails.config.server_url
        expected_iss = File.join(KeycloakApiRails.config.server_url.to_s, "realms", realm_id.to_s)
        raise TokenError.invalid_realm(token) unless decoded_token["iss"] == expected_iss
      end
    end

    def not_before_is_invalid?(token)
      @verify_not_before && token.key?("nbf") && !token["nbf"].is_a?(Numeric)
    end

    # Anything that is not a regexp is discarded rather than matched: 'String#match' compiles its
    # argument into a regexp, so a String would be matched against the path of the request instead of
    # the other way around, and would open every path that is a sub-pattern of it. The railtie rejects
    # such a configuration when the application boots; a Rack application running without Rails never
    # calls 'validate!', so the paths keep being authenticated here.
    def normalize_skip_paths(skip_paths, logger)
      (skip_paths || {}).each_with_object({}) do |(method, paths), normalized|
        regexps, discarded = Array(paths).partition { |path| path.is_a?(Regexp) }

        unless discarded.empty?
          logger&.warn("KeycloakApiRails: 'skip_paths[#{method.inspect}]' declares #{discarded.map(&:inspect).join(', ')}, which are not regexps. They are ignored, and the paths they were meant to open keep being authenticated.")
        end

        line_anchored = regexps.select { |regexp| line_anchored?(regexp) }
        unless line_anchored.empty?
          logger&.warn("KeycloakApiRails: 'skip_paths[#{method.inspect}]' declares #{line_anchored.map(&:inspect).join(', ')}, anchored with '^' or '$'. In Ruby those match the beginning and the end of a line, not of the path: \"/private\\n/health\" matches /^\\/health/ and skips authentication. Anchor with '\\A' and '\\z'.")
        end

        normalized[method.to_s.upcase] = regexps
      end
    end

    # Escaped pairs are dropped first, so that '\^' does not count and '[^/]' is read as a class.
    def line_anchored?(regexp)
      regexp.source.gsub(/\\./, "").gsub(/\[[^\]]*\]/, "").match?(/[\^$]/)
    end

    def should_skip?(method, path)
      skip_paths = @skip_paths[method]
      !skip_paths.nil? && skip_paths.any? { |skip_path| skip_path.match?(path) }
    end

    def is_preflight?(method, headers)
      method == "OPTIONS" && !headers["HTTP_ACCESS_CONTROL_REQUEST_METHOD"].nil?
    end

    def expired?(token)
      token_expiration = Time.at(token["exp"])
      token_expiration < Time.now + @token_expiration_tolerance_in_seconds
    end

    def not_yet_valid?(token)
      return false unless @verify_not_before

      not_before = token["nbf"]
      !not_before.nil? && Time.at(not_before) > Time.now
    end

    def audience_valid?(token)
      return true if @expected_audiences.empty?

      Array(token["aud"]).any? { |audience| @expected_audiences.include?(audience.to_s) }
    end

    def token_type_valid?(token)
      return true if @expected_token_type.nil?

      token["typ"].to_s.casecmp?(@expected_token_type)
    end
  end
end
