module KeycloakApiRails
  class MissingPublicKeysError < StandardError; end

  class Service

    def initialize(key_resolver)
      configuration                          = KeycloakApiRails.config
      @key_resolver                          = key_resolver
      @skip_paths                            = normalize_skip_paths(configuration.skip_paths)
      @opt_in                                = configuration.opt_in
      @token_expiration_tolerance_in_seconds = configuration.token_expiration_tolerance_in_seconds
      @expected_audiences                    = Array(configuration.expected_audience).map(&:to_s)
      @expected_token_type                   = configuration.expected_token_type
      @verify_not_before                     = configuration.verify_not_before
      @allow_token_in_query_string           = configuration.allow_token_in_query_string
    end

    def decode_and_verify(token)
      raise TokenError.no_token(token) if token.nil? || token.empty?

      public_keys = @key_resolver.find_public_keys
      
      if public_keys.nil?
        raise MissingPublicKeysError, "No Keycloak public key is available to verify the token" 
      end

      decoded_token = decode(token, public_keys)
      verify_claims!(token, decoded_token)
      decoded_token
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
      decoded_token = JSON::JWT.decode(token, public_keys)
      decoded_token.verify!(public_keys)
      decoded_token
    rescue JSON::JWT::VerificationFailed, JSON::JWK::Set::KidNotFound => e
      raise TokenError.verification_failed(token, e)
    rescue JSON::JWT::InvalidFormat => e
      raise TokenError.invalid_format(token, e)
    rescue StandardError => e
      raise TokenError.unknown(token, e)
    end

    def verify_claims!(token, decoded_token)
      raise TokenError.missing_claim(token, "exp") unless decoded_token.key?("exp")
      raise TokenError.expired(token)              if expired?(decoded_token)
      raise TokenError.not_yet_valid(token)        if not_yet_valid?(decoded_token)
      raise TokenError.invalid_audience(token)     unless audience_valid?(decoded_token)
      raise TokenError.invalid_token_type(token)   unless token_type_valid?(decoded_token)
    end

    def normalize_skip_paths(skip_paths)
      (skip_paths || {}).each_with_object({}) do |(method, paths), normalized|
        normalized[method.to_s.downcase.to_sym] = Array(paths)
      end
    end

    def should_skip?(method, path)
      skip_paths = @skip_paths[method&.to_s&.downcase&.to_sym]
      !skip_paths.nil? && skip_paths.any? { |skip_path| skip_path.match(path) }
    end

    def is_preflight?(method, headers)
      method_symbol = method&.to_s&.downcase&.to_sym
      method_symbol == :options && !headers["HTTP_ACCESS_CONTROL_REQUEST_METHOD"].nil?
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
