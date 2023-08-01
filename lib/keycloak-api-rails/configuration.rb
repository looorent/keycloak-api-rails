module Keycloak
  Configuration = Struct.new(
    :server_url,
    :realm_id,
    :skip_paths,
    :opt_in,
    :token_expiration_tolerance_in_seconds,
    :public_key_cache_ttl,
    :custom_attributes,
    :logger,
    :ca_certificate_file,
    keyword_init: true
  ) do
    def self.from(request)
      config_block = Keycloak.configuration_block.call(request)
      new.tap { |config| config_block.call(config) }
    end
  end
end
