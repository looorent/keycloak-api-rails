module Keycloak
  class Configuration
    include ActiveSupport::Configurable
    config_accessor :server_url
    config_accessor :realm_id
    config_accessor :token_expiration_tolerance_in_seconds
    config_accessor :public_key_cache_ttl
    config_accessor :custom_attributes
    config_accessor :logger
    config_accessor :ca_certificate_file
  end
end
