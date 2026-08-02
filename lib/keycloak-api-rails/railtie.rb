# frozen_string_literal: true

module KeycloakApiRails
  class Railtie < Rails::Railtie
    railtie_name :keycloak_api_rails

    initializer("keycloak.insert_middleware") do |app|
      app.config.middleware.use(KeycloakApiRails::Middleware)
    end

    # Runs once every initializer has run, config/initializers/keycloak.rb included, so that a
    # misconfiguration fails at boot instead of on the first request reaching the middleware.
    config.after_initialize do
      keycloak_configuration = KeycloakApiRails.config
      keycloak_configuration.validate!

      unless keycloak_configuration.server_configured?
        keycloak_configuration.logger.warn(
          "KeycloakApiRails: 'server_url' and 'realm_id' are not both configured. No token can be " \
          "verified until they are, unless the public key resolver is replaced -- as " \
          "\"keycloak-api-rails/testing\" does."
        )
      end
    end
  end
end
