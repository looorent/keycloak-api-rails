module KeycloakApiRails
  class TokenError < StandardError
    attr_reader :token, :reason, :original_error

    def initialize(token, reason, message, original_error = nil)
      super(message)
      @token          = token
      @reason         = reason
      @original_error = original_error
    end

    def self.verification_failed(token, original_error)
      new(token, :verification_failed, "Failed to verify JWT token", original_error)
    end

    def self.invalid_format(token, original_error)
      new(token, :invalid_format, "Wrong JWT Format", original_error)
    end

    def self.no_token(token)
      new(token, :no_token, "No JWT token provided")
    end

    def self.expired(token)
      new(token, :expired, "JWT token is expired")
    end

    def self.not_yet_valid(token)
      new(token, :not_yet_valid, "JWT token is not valid yet")
    end

    def self.invalid_audience(token)
      new(token, :invalid_audience, "JWT token has been issued for another audience")
    end

    def self.invalid_token_type(token)
      new(token, :invalid_token_type, "JWT token is not of the expected type")
    end

    def self.missing_claim(token, claim)
      new(token, :missing_claim, "JWT token does not carry the mandatory claim '#{claim}'")
    end

    def self.unknown(token, original_error)
      new(token, :unknown, "Failed to read JWT token", original_error)
    end
  end
end
