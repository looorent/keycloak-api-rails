module Keycloak
  class Service
    
    def initialize(key_resolver)
      @key_resolver                          = key_resolver
      @skip_paths                            = Keycloak.config.skip_paths
      @logger                                = Keycloak.config.logger
      @token_expiration_tolerance_in_seconds = Keycloak.config.token_expiration_tolerance_in_seconds
    end

    def decode_and_verify(token)
      unless token.nil? || token&.empty?
        public_key    = @key_resolver.find_public_keys
        decoded_token = JSON::JWT.decode(token, public_key)

        unless expired?(decoded_token)
          decoded_token.verify!(public_key)
          decoded_token
        else
          raise TokenError.expired(token)
        end
      else
        raise TokenError.no_token(token)
      end
    rescue JSON::JWT::VerificationFailed => e
      raise TokenError.verification_failed(token, e)
    rescue JWK::Set::KidNotFound => e
      raise TokenError.verification_failed(token, e)
    rescue JSON::JWT::InvalidFormat
      raise TokenError.invalid_format(token, e)
    end

    def read_token(uri, headers)
      parsed_uri           = URI.parse(uri)
      query                = URI.decode_www_form(parsed_uri.query || "")
      query_string_token   = query.detect { |param| param.first == "authorizationToken" }

      if query_string_token
        query_string_token.second
      else
        headers["HTTP_AUTHORIZATION"]&.gsub(/^Bearer /, "") || ""
      end
    end

    def need_authentication?(method, path)
      method_symbol = method&.downcase&.to_sym
      skip_paths    = @skip_paths[method_symbol]
      skip_paths.nil? || skip_paths.empty? || skip_paths.find_index { |skip_path| skip_path.match(path) }.nil?
    end

    private

    def expired?(token)
      token_expiration = Time.at(token["exp"]).to_datetime
      token_expiration < Time.now + @token_expiration_tolerance_in_seconds.seconds
    end
  end
end
