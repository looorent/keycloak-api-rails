module Keycloak

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if Keycloak.config.server_url.present?
        authenticate(env)
      else
        @app.call(env)
      end
    end

    def authenticate(env)
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]
      query_string = env["QUERY_STRING"]
      
      if service.need_authentication?(method, path, query_string, env)
        logger.debug("Start authentication for #{method} : #{path}")
        token         = service.read_token(query_string, env)
        decoded_token = service.decode_and_verify(token)
        authentication_succeeded(env, decoded_token)
      else
        logger.debug("Skip authentication for #{method} : #{path}")
        @app.call(env)
      end
    rescue TokenError => e
      # authentication_failed(e.message)

      # WTS-881 added failed msg to be captured by controller
      # to make sure the logger to log the request and got shipped to datadog
      # continue the request
      env[:identity_auth_error_message] = e.message
      @app.call(env)
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
