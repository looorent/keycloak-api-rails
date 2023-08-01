require "logger"
require "json/jwt"
require "uri"
require "date"
require "net/http"

require_relative "keycloak-api-rails/authentication"
require_relative "keycloak-api-rails/configuration"
require_relative "keycloak-api-rails/http_client"
require_relative "keycloak-api-rails/token_error"
require_relative "keycloak-api-rails/helper"
require_relative "keycloak-api-rails/public_key_resolver"
require_relative "keycloak-api-rails/public_key_cached_resolver"
require_relative "keycloak-api-rails/service"
require_relative "keycloak-api-rails/middleware"
require_relative "keycloak-api-rails/railtie" if defined?(Rails)

module Keycloak
  def self.configure(&block)
    @configure_block = block
  end

  def self.load_configuration
    lambda do |_request|
      configure do |config|
        config.server_url                             = nil
        config.realm_id                               = nil
        config.logger                                 = ::Logger.new(STDOUT)
        config.skip_paths                             = {}
        config.opt_in                                 = false
        config.token_expiration_tolerance_in_seconds  = 10
        config.public_key_cache_ttl                   = 86400
        config.custom_attributes                      = []
      end
    end
  end

  load_configuration
end
