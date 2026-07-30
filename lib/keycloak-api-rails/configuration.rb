module KeycloakApiRails
  class Configuration
    attr_accessor :server_url
    attr_accessor :realm_id
    attr_accessor :skip_paths
    attr_accessor :opt_in
    attr_accessor :token_expiration_tolerance_in_seconds
    attr_accessor :public_key_cache_ttl
    attr_accessor :custom_attributes
    attr_accessor :logger
    attr_accessor :ca_certificate_file
  end
end
