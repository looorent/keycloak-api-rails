module KeycloakApiRails
  class ControllablePublicKeyResolverStub
    attr_reader :calls

    def initialize(public_keys, delay: 0)
      @public_keys = public_keys
      @delay       = delay
      @calls       = 0
      @unreachable = false
      @mutex       = Mutex.new
    end

    def become_unreachable!
      @unreachable = true
    end

    def find_public_keys(realm_id = nil)
      @mutex.synchronize { @calls += 1 }
      sleep(@delay) if @delay > 0
      raise HTTPError, "Keycloak is unreachable" if @unreachable

      @public_keys
    end
  end
end
