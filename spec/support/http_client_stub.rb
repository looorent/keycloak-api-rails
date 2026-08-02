module KeycloakApiRails
  class HTTPClientStub
    def initialize(jwks_by_realm = {})
      @jwks_by_realm = jwks_by_realm
      @realms        = []
      @mutex         = Mutex.new
    end

    def realms
      @mutex.synchronize { @realms.dup }
    end

    def get(realm_id, _path)
      @mutex.synchronize { @realms << realm_id }

      { "keys" => @jwks_by_realm.fetch(realm_id, []) }
    end
  end
end
