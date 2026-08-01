require_relative "../../lib/keycloak-api-rails/testing"

RSpec.describe KeycloakApiRails::Testing do
  include KeycloakApiRails::Testing::Helpers

  # The tokens are validated by the real middleware and the real service, so that these examples
  # fail if what this module forges stops being what the library expects.
  let(:authenticated_env) { {} }
  let(:app) do
    downstream = lambda do |env|
      authenticated_env.replace(env)
      [200, {}, ["OK"]]
    end
    KeycloakApiRails::Middleware.new(downstream)
  end

  def get(headers)
    app.call({
      "REQUEST_METHOD"    => "GET",
      "PATH_INFO"         => "/me",
      "REQUEST_URI"       => "http://example.org/me",
      "HTTP_AUTHORIZATION" => headers["Authorization"]
    })
  end

  before(:each) do
    # The middleware only authenticates a request when the configuration tells it to, and the
    # configuration is global: these examples cannot rely on what the other ones leave behind.
    KeycloakApiRails.config.opt_in    = false
    KeycloakApiRails.config.skip_paths = {}
    @logger = KeycloakApiRails.config.logger
    KeycloakApiRails.config.logger = ::Logger.new(File::NULL)
    KeycloakApiRails::Testing.stub_public_keys!
  end

  after(:each) do
    KeycloakApiRails.config.logger       = @logger
    KeycloakApiRails.public_key_resolver = nil
  end

  describe ".stub_public_keys!" do
    it "should validate the tokens forged by this module" do
      status, _headers, _body = get(keycloak_auth_headers)

      expect(status).to eq(200)
    end

    it "should not require a Keycloak server to be configured" do
      expect(KeycloakApiRails.config.server_url).to be_nil
      expect(KeycloakApiRails.config.realm_id).to be_nil

      status, _headers, _body = get(keycloak_auth_headers)

      expect(status).to eq(200)
    end
  end

  describe ".token_for" do
    it "should authenticate the given user" do
      get(keycloak_auth_headers(sub: "a-keycloak-id"))

      expect(KeycloakApiRails::Helper.current_user_id(authenticated_env)).to eq("a-keycloak-id")
    end

    it "should generate a different user for each token" do
      first_token  = JSON::JWT.decode(keycloak_token, KeycloakApiRails::Testing.public_keys)
      second_token = JSON::JWT.decode(keycloak_token, KeycloakApiRails::Testing.public_keys)

      expect(first_token["sub"]).not_to eq(second_token["sub"])
    end

    it "should expose every claim read by the library" do
      get(keycloak_auth_headers(sub:              "a-keycloak-id",
                                email:            "an-email@keycloak.io",
                                locale:           "fr",
                                authorized_party: "a-client",
                                roles:            ["admin", "user"],
                                resource_roles:   { "a-client" => ["reader"] }))

      expect(KeycloakApiRails::Helper.current_user_id(authenticated_env)).to eq("a-keycloak-id")
      expect(KeycloakApiRails::Helper.current_user_email(authenticated_env)).to eq("an-email@keycloak.io")
      expect(KeycloakApiRails::Helper.current_user_locale(authenticated_env)).to eq("fr")
      expect(KeycloakApiRails::Helper.current_authorized_party(authenticated_env)).to eq("a-client")
      expect(KeycloakApiRails::Helper.current_user_roles(authenticated_env)).to eq(["admin", "user"])
      expect(KeycloakApiRails::Helper.current_resource_roles(authenticated_env)).to eq({ "a-client" => ["reader"] })
    end

    it "should expose the claims declared as custom attributes" do
      KeycloakApiRails.config.custom_attributes = ["tenant_id"]

      get(keycloak_auth_headers(claims: { "tenant_id" => "a-tenant" }))

      expect(KeycloakApiRails::Helper.current_user_custom_attributes(authenticated_env)).to eq({ "tenant_id" => "a-tenant" })
    ensure
      KeycloakApiRails.config.custom_attributes = []
    end

    it "should forge a token that is expired when 'expires_at' is in the past" do
      status, _headers, body = get(keycloak_auth_headers(issued_at: Time.now - 7200, expires_at: Time.now - 3600))

      expect(status).to eq(401)
      expect(body.first).to include("JWT token is expired")
    end
  end
end
