module KeycloakApiRails
  # One RSA key pair per realm, generated once for the whole suite: generating one is by far the
  # slowest thing a spec that forges tokens does.
  module RealmKeys
    class << self
      def signing_jwk(realm)
        JSON::JWK.new(private_key(realm), kid: realm)
      end

      def public_jwk(realm)
        JSON::JWK.new(private_key(realm).public_key, kid: realm)
      end

      private

      def private_key(realm)
        @private_keys        ||= {}
        @private_keys[realm] ||= OpenSSL::PKey::RSA.generate(2048)
      end
    end
  end
end
