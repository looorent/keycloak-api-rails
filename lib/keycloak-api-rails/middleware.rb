module Keycloak
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      service = ServiceFactory.from_env(env)
      service.authenticate!(env)
      @app.call(env)
    rescue TokenError => e
      authentication_failed(e.message)
    end

    def authentication_failed(message)
      [401, {"Content-Type" => "application/json"}, [ { error: message }.to_json]]
    end
  end
end
