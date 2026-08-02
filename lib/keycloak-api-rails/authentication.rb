# frozen_string_literal: true

module KeycloakApiRails
  module Authentication
    def self.included(base)
      if base.respond_to?(:helper_method)
        base.helper_method :keycloak_authenticate
      end
    end

    protected

    def keycloak_authenticate
      env    = request.env
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]

      KeycloakApiRails.logger.debug("Start authentication for #{method} : #{path}")
      token         = KeycloakApiRails.service.read_token(Helper.request_uri(env), env)
      decoded_token = KeycloakApiRails.service.decode_and_verify(token)
      authentication_succeeded(env, decoded_token)
    rescue TokenError => e
      authentication_failed(e.message)
    rescue KeycloakApiRails::HTTPError, KeycloakApiRails::MissingPublicKeysError => e
      authentication_unavailable(e)
    end

    def authentication_failed(message)
      KeycloakApiRails.logger.info(message)
      render status: :unauthorized, json: { error: message }
    end

    def authentication_unavailable(error)
      KeycloakApiRails.logger.error("KeycloakApiRails: no token can be verified. #{error.class}: #{error.message}")
      response.headers["Retry-After"] = KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS.to_s
      render status: :service_unavailable, json: { error: "Authentication is temporarily unavailable" }
    end

    def authentication_succeeded(env, decoded_token)
      Helper.assign_token(env, decoded_token, KeycloakApiRails.config.custom_attributes)
    end
  end
end
