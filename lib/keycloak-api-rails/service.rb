module Keycloak
  class Service
    
    def initialize(key_resolver)
      @key_resolver                          = key_resolver
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
    rescue JSON::JWK::Set::KidNotFound => e
      raise TokenError.verification_failed(token, e)
    rescue JSON::JWT::InvalidFormat
      raise TokenError.invalid_format(token, e)
    end

    def read_token(uri, headers)
      Helper.read_token_from_query_string(uri) || Helper.read_token_from_headers(headers)
    end

    private

    def expired?(token)
      token_expiration = Time.at(token["exp"]).to_datetime
      token_expiration < Time.now + @token_expiration_tolerance_in_seconds.seconds
    end
  end
end
