module Keycloak
  class PublicKeyResolver
    def initialize(server_url, realm_id)
      @public_certificate_url = create_public_certificate_url(server_url, realm_id)
    end

    def find_public_keys
      JSON::JWK::Set.new(JSON.parse(RestClient.get(@public_certificate_url).body)["keys"])
    end

    private

    def create_realm_url(server_url, realm_id)
      "#{server_url}/realms/#{realm_id}"
    end

    def create_public_certificate_url(server_url, realm_id)
      "#{create_realm_url(server_url, realm_id)}/protocol/openid-connect/certs"
    end
  end
end