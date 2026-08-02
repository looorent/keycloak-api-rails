# frozen_string_literal: true

require "logger"
require "json/jwt"
require "uri"
require "date"
require "monitor"
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

module KeycloakApiRails

  # These objects are memoized lazily, on the first request each process serves -- which several
  # threads of a threaded server reach at the same time. A Monitor rather than a Mutex: the
  # memoizations nest, 'service' needing 'public_key_resolver', which needs 'http_client'.
  MONITOR = Monitor.new

  def self.configure
    MONITOR.synchronize do
      yield @configuration ||= KeycloakApiRails::Configuration.new
      discard_configured_objects
    end
  end

  def self.discard_configured_objects
    @http_client         = nil
    @public_key_resolver = nil unless @public_key_resolver_assigned
    @service             = nil
  end
  private_class_method :discard_configured_objects

  def self.config
    @configuration
  end

  def self.http_client
    MONITOR.synchronize { @http_client ||= KeycloakApiRails::HTTPClient.new(config, logger) }
  end

  def self.public_key_resolver
    MONITOR.synchronize { @public_key_resolver ||= PublicKeyCachedResolver.from_configuration(http_client, config) }
  end

  # Mainly used by "keycloak-api-rails/testing" to validate tokens without a Keycloak server.
  # Assigning nil restores the regular resolver. The memoized service is discarded, since it holds
  # a reference to the resolver that is being replaced.
  def self.public_key_resolver=(resolver)
    MONITOR.synchronize do
      @public_key_resolver          = resolver
      @public_key_resolver_assigned = !resolver.nil?
      @service                      = nil
    end
  end

  def self.service
    MONITOR.synchronize { @service ||= KeycloakApiRails::Service.new(public_key_resolver) }
  end

  def self.logger
    config.logger
  end

  def self.load_configuration
    configure do |config|
      config.server_url                             = nil
      config.realm_id                               = nil
      config.logger                                 = ::Logger.new(STDOUT)
      config.skip_paths                             = {}
      config.opt_in                                 = false
      config.token_expiration_tolerance_in_seconds  = 10
      config.public_key_cache_ttl                   = 86400
      config.custom_attributes                      = []
      config.ca_certificate_file                    = nil
      config.expected_audience                      = nil
      config.expected_token_type                    = nil
      config.verify_not_before                      = false
      config.allow_token_in_query_string            = false
      config.http_open_timeout                      = 5
      config.http_read_timeout                      = 5
      config.allowed_algorithms                     = KeycloakApiRails::Service::SUPPORTED_ALGORITHMS
    end
  end

  load_configuration
end
