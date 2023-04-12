module Keycloak
  module Authentication
    extend ActiveSupport::Concern

    included do
      if respond_to?(:helper_method)
        helper_method :keycloak_authenticate
      end
    end

    protected

    def keycloak_authenticate
      
      env = request.env
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]
      uri    = env["REQUEST_URI"]

      logger.debug("Start authentication for #{method} : #{path}")
      token         = service.read_token(uri, env)
      decoded_token = service.decode_and_verify(token)
      authentication_succeeded(env, decoded_token)
      
    rescue TokenError => e
      authentication_failed(e.message)
    end

    def authentication_failed(message)
      logger.info(message)
      render status: :unauthorized, json: { error: "Invalid Token" }
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