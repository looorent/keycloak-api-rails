# frozen_string_literal: true

module KeycloakApiRails

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      method = env["REQUEST_METHOD"]
      path   = env["PATH_INFO"]

      if service.need_middleware_authentication?(method, path, env)
        logger.debug("Start authentication for #{method} : #{path}")
        begin
          authenticate(env)
        rescue TokenError => e
          logger.debug("The error causing the Token to fail: #{e.original_error&.message || e.message}")
          return authentication_failed(e.message)
        rescue HTTPError, MissingPublicKeysError => e
          logger.error("KeycloakApiRails: no token can be verified for #{method} : #{path}. #{e.class}: #{e.message}")
          return authentication_unavailable
        end
      else
        logger.debug("Skip authentication for #{method} : #{path}")
      end

      @app.call(env)
    end

    private

    def authenticate(env)
      token         = service.read_token(Helper.request_uri(env), env)
      decoded_token = service.decode_and_verify(token)
      Helper.assign_token(env, decoded_token, config.custom_attributes)
    end

    def authentication_failed(message)
      # Rack 3 requires header names to be lowercase.
      [401, { "content-type" => "application/json" }, [{ error: message }.to_json]]
    end

    def authentication_unavailable
      [503,
       { "content-type" => "application/json",
         "retry-after"  => PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS.to_s },
       [{ error: "Authentication is temporarily unavailable" }.to_json]]
    end

    def service
      KeycloakApiRails.service
    end

    def logger
      KeycloakApiRails.logger
    end

    def config
      KeycloakApiRails.config
    end
  end
end
