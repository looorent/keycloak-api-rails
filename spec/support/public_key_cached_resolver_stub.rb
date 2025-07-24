module KeycloakApiRails
  class PublicKeyCachedResolverStub
    def initialize(public_key)
      @public_key = public_key
    end

    def find_public_keys
      @public_key
    end
  end
end
