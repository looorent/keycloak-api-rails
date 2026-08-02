RSpec.describe "Multi-tenancy" do

  let(:server_url) { "https://keycloak.example.org" }

  let(:keycloak) do
    KeycloakApiRails::HTTPClientStub.new(
      "tenant-1" => [KeycloakApiRails::RealmKeys.public_jwk("tenant-1")],
      "tenant-2" => [KeycloakApiRails::RealmKeys.public_jwk("tenant-2")]
    )
  end

  after(:each) do
    KeycloakApiRails.public_key_resolver = nil
    KeycloakApiRails.load_configuration
  end

  def service_for(realm_id)
    KeycloakApiRails.configure do |config|
      config.server_url = server_url
      config.realm_id   = realm_id
      config.logger     = ::Logger.new(File::NULL)
    end
    KeycloakApiRails.public_key_resolver =
      KeycloakApiRails::PublicKeyCachedResolver.from_configuration(keycloak, KeycloakApiRails.config)

    KeycloakApiRails.service
  end

  # 'signed_by' is the realm whose private key signs, 'iss' the realm the token claims to come from:
  # they are the same for a token Keycloak really issued.
  def token(signed_by, iss: File.join(server_url, "realms", signed_by))
    payload = { "sub" => "a-user", "exp" => (Time.now + 3600).to_i }
    payload["iss"] = iss unless iss.nil?

    JSON::JWT.new(payload).sign(KeycloakApiRails::RealmKeys.signing_jwk(signed_by), :RS256).to_s
  end

  def expect_invalid_realm(service, token)
    expect {
      service.decode_and_verify(token)
    }.to raise_error(KeycloakApiRails::TokenError, "JWT token does not have a valid realm")
  end

  context "when a single realm is configured" do
    let(:service) { service_for("tenant-1") }

    it "accepts a token issued by that realm" do
      expect(service.decode_and_verify(token("tenant-1"))).to_not be_nil
    end

    it "rejects a token issued by another realm of the same server" do
      expect_invalid_realm(service, token("tenant-2"))
    end

    it "does not download the keys of a realm it refuses" do
      expect_invalid_realm(service, token("tenant-2"))

      expect(keycloak.realms).to be_empty
    end
  end

  context "when several realms are configured" do
    let(:service) { service_for(["tenant-1", "tenant-2"]) }

    it "accepts a token issued by any of them" do
      expect(service.decode_and_verify(token("tenant-1"))).to_not be_nil
      expect(service.decode_and_verify(token("tenant-2"))).to_not be_nil
    end

    it "rejects a token issued by a realm outside the list" do
      expect_invalid_realm(service, token("tenant-3"))
    end

    it "downloads the keys of each realm, once each" do
      2.times { service.decode_and_verify(token("tenant-1")) }
      2.times { service.decode_and_verify(token("tenant-2")) }

      expect(keycloak.realms).to eq ["tenant-1", "tenant-2"]
    end

    # The realms share a server, not their keys: whoever signs for one must not sign for the other.
    it "does not verify a token with the keys of another realm" do
      forged = token("tenant-1", iss: File.join(server_url, "realms", "tenant-2"))

      expect {
        service.decode_and_verify(forged)
      }.to raise_error(KeycloakApiRails::TokenError, "Failed to verify JWT token")
      expect(keycloak.realms).to eq ["tenant-2"]
    end
  end

  context "when the realms are decided by a Proc" do
    it "asks it about the realm the token names" do
      asked   = []
      service = service_for(->(realm) { asked << realm; true })

      service.decode_and_verify(token("tenant-1"))

      expect(asked).to eq ["tenant-1"]
    end

    it "rejects the token when it answers false" do
      expect_invalid_realm(service_for(->(_realm) { false }), token("tenant-1"))
    end

    # Its answer says whether the realm is allowed. It does not name the realm to trust instead.
    it "reads anything else it answers as a yes, and keeps the realm of the token" do
      service = service_for(->(_realm) { "tenant-2" })

      expect(service.decode_and_verify(token("tenant-1"))).to_not be_nil
      expect(keycloak.realms).to eq ["tenant-1"]
    end
  end

  context "when the token names an issuer of its own" do
    let(:service) { service_for("tenant-1") }

    # The realm is allowed and the signature checks out: only the issuer gives this one away.
    it "rejects a token issued by another server" do
      expect_invalid_realm(service, token("tenant-1", iss: "https://keycloak.attacker.example/realms/tenant-1"))

      expect(keycloak.realms).to eq ["tenant-1"]
    end

    it "rejects a token carrying no issuer at all" do
      expect_invalid_realm(service, token("tenant-1", iss: nil))

      expect(keycloak.realms).to be_empty
    end
  end
end
