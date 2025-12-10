module KeycloakApiRails
  class Railtie < Rails::Railtie
    railtie_name :keycloak_api_rails

    initializer("keycloak.insert_middleware") do |app|
      app.config.middleware.use(KeycloakApiRails::Middleware)
    end
  end
end