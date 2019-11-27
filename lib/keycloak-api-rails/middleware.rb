module Keycloak

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]
      uri    = env["REQUEST_URI"]

      if service.need_authentication?(method, path, env)
        logger.debug("Start authentication for #{method} : #{path}")
        token         = service.read_token(uri, env)
        decoded_token = service.decode_and_verify(token)
        authentication_succeeded(env, decoded_token)
      else
        logger.debug("Skip authentication for #{method} : #{path}")
        @app.call(env)
      end
    rescue TokenError => e
      authentication_failed(e.message)
    end

    def authentication_failed(message)
      logger.info(message)
      [401, {"Content-Type" => "application/json"}, [ { error: message }.to_json]]
    end

    def authentication_succeeded(env, decoded_token)
      Helper.assign_current_user_id(env, decoded_token)
      Helper.assign_current_authorized_party(env, decoded_token)
      Helper.assign_current_user_email(env, decoded_token)
      Helper.assign_current_user_locale(env, decoded_token)
      Helper.assign_current_user_custom_attributes(env, decoded_token, config.custom_attributes)
      Helper.assign_realm_roles(env, decoded_token)
      Helper.assign_resource_roles(env, decoded_token)
      Helper.assign_keycloak_token(env, decoded_token)
      @app.call(env)
    end

    def service
      Keycloak.service
    end

    def logger
      Keycloak.logger
    end

    def config
      Keycloak.config
    end
  end
end
