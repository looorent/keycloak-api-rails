module KeycloakApiRails
  class HTTPClientStub
    def initialize
      @realms = []
      @mutex  = Mutex.new
    end

    def realms
      @mutex.synchronize { @realms.dup }
    end

    def get(realm_id, _path)
      @mutex.synchronize { @realms << realm_id }

      { "keys" => [] }
    end
  end
end
