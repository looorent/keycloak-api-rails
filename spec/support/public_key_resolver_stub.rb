module Keycloak
  class PublicKeyResolverStub
    def find_public_keys
      OpenSSL::PKey::RSA.generate(1024).public_key
    end
  end
end
