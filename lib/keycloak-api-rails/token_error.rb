class TokenError < StandardError
  attr_reader :token, :reason, :original_error

  def initialize(token, reason, message, original_error)
    super(message)
    @token          = token
    @reason         = reason
    @original_error = original_error
  end

  def self.verification_failed(token, original_error)
    TokenError.new(token, :verification_failed, "Failed to verify JWT token", original_error)
  end

  def self.invalid_format(token, original_error)
    TokenError.new(token, :invalid_format, "Wrong JWT Format", original_error)
  end

  def self.no_token(token)
    TokenError.new(token, :no_token, "No JWT token provided", nil)
  end

  def self.expired(token)
    TokenError.new(token, :expired, "JWT token is expired", nil)
  end

  def self.unknown(token)
    TokenError.new
  end
end
