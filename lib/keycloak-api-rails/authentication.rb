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
      service = ServiceFactory.from_env(env)
      service.authenticate!(env)
    rescue TokenError => e
      authentication_failed(e.message)
    end

    def authentication_failed(message)
      render status: :unauthorized, json: { error: message }
    end

    def authentication_succeeded(env, decoded_token)
      Helper.assign_current_user_id(env, decoded_token)
      Helper.assign_current_authorized_party(env, decoded_token)
      Helper.assign_current_user_email(env, decoded_token)
      Helper.assign_current_user_locale(env, decoded_token)
      Helper.assign_current_user_custom_attributes(env, decoded_token, Keycloak.config.custom_attributes)
      Helper.assign_realm_roles(env, decoded_token)
      Helper.assign_resource_roles(env, decoded_token)
      Helper.assign_keycloak_token(env, decoded_token)
    end
  end
end
