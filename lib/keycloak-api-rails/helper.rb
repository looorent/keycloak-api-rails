module Keycloak
  class Helper
    
    CURRENT_USER_ID_KEY = "keycloak:keycloak_id"
    ROLES_KEY           = "keycloak:roles"

    def self.current_user_id(env)
      env[CURRENT_USER_ID_KEY]
    end

    def self.assign_current_user_id(env, token)
      env[CURRENT_USER_ID_KEY] = token["sub"]
    end

    def self.current_user_roles(env)
      env[ROLES_KEY]
    end

    def self.assign_realm_roles(env, token)
      env[ROLES_KEY] = token.dig("realm_access", "roles")
    end
  end
end
