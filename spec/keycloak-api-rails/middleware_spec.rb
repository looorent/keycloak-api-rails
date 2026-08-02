require "rack"
require "rack/lint"
require "keycloak-api-rails/testing"

RSpec.describe KeycloakApiRails::Middleware do

  let(:downstream_response) { [200, { "content-type" => "text/plain" }, ["downstream"]] }
  let(:downstream)          { ->(env) { @downstream_env = env; downstream_response } }
  let(:app)                 { KeycloakApiRails::Middleware.new(downstream) }

  before(:each) do
    KeycloakApiRails.load_configuration
    KeycloakApiRails.config.logger = ::Logger.new(File::NULL)
    KeycloakApiRails::Testing.stub_public_keys!
    @downstream_env = nil
  end

  after(:each) do
    KeycloakApiRails.public_key_resolver = nil
    KeycloakApiRails.load_configuration
  end

  def rack_3?
    Rack.release.split(".").first.to_i >= 3
  end

  def env_for(path, headers: {}, method: "GET")
    Rack::MockRequest.env_for("https://api.example.org#{path}", method: method).merge(headers)
  end

  def call(path, headers: {}, method: "GET")
    @response = app.call(env_for(path, headers: headers, method: method))
  end

  def authorization_headers(**options)
    { "HTTP_AUTHORIZATION" => "Bearer #{KeycloakApiRails::Testing.token_for(**options)}" }
  end

  def status
    @response[0]
  end

  def headers
    @response[1]
  end

  def body
    @response[2].to_a.join
  end

  def error
    JSON.parse(body)["error"]
  end

  describe "when the token is valid" do
    let(:token_options) { { sub: "a-keycloak-id", email: "user@example.org", roles: ["admin"] } }

    it "calls the downstream application" do
      call("/things", headers: authorization_headers(**token_options))

      expect(status).to eq 200
      expect(body).to eq "downstream"
    end

    it "exposes the claims of the token to the downstream application" do
      call("/things", headers: authorization_headers(**token_options))

      expect(KeycloakApiRails::Helper.current_user_id(@downstream_env)).to eq "a-keycloak-id"
      expect(KeycloakApiRails::Helper.current_user_email(@downstream_env)).to eq "user@example.org"
      expect(KeycloakApiRails::Helper.current_user_roles(@downstream_env)).to eq ["admin"]
      expect(KeycloakApiRails::Helper.keycloak_token(@downstream_env)).to_not be_nil
    end

    it "exposes the custom attributes declared as Strings" do
      KeycloakApiRails.config.custom_attributes = ["tenant_id"]

      call("/things", headers: authorization_headers(claims: { "tenant_id" => 42 }))

      expect(KeycloakApiRails::Helper.current_user_custom_attributes(@downstream_env)).to eq({ "tenant_id" => 42 })
    end

    it "exposes the custom attributes declared as Symbols" do
      KeycloakApiRails.config.custom_attributes = [:tenant_id]

      call("/things", headers: authorization_headers(claims: { "tenant_id" => 42 }))

      expect(KeycloakApiRails::Helper.current_user_custom_attributes(@downstream_env)).to eq({ "tenant_id" => 42 })
    end

    # 'REQUEST_URI' is absent from a Rack::Test environment, which used to make the middleware
    # ignore the 'Authorization' header entirely.
    it "reads the header of a request whose environment carries no 'REQUEST_URI'" do
      env = env_for("/things", headers: authorization_headers(**token_options))
      expect(env).to_not have_key "REQUEST_URI"

      expect(app.call(env).first).to eq 200
    end

    it "ignores a token passed through the query string by default" do
      token = KeycloakApiRails::Testing.token_for(**token_options)

      call("/things?authorizationToken=#{token}")

      expect(status).to eq 401
    end

    it "accepts a token passed through the query string once it is allowed to" do
      KeycloakApiRails.config.allow_token_in_query_string = true
      token = KeycloakApiRails::Testing.token_for(**token_options)

      call("/things?authorizationToken=#{token}")

      expect(status).to eq 200
    end

    it "prefers the token of the 'Authorization' header over the one of the query string" do
      KeycloakApiRails.config.allow_token_in_query_string = true
      query_string_token = KeycloakApiRails::Testing.token_for(sub: "the-query-string-user")

      call("/things?authorizationToken=#{query_string_token}", headers: authorization_headers(**token_options))

      expect(status).to eq 200
      expect(KeycloakApiRails::Helper.current_user_id(@downstream_env)).to eq "a-keycloak-id"
    end

    it "honours a configuration change applied once a request has been served" do
      call("/things", headers: authorization_headers(**token_options))
      expect(status).to eq 200

      KeycloakApiRails.configure { |config| config.expected_audience = "my-api" }

      call("/things", headers: authorization_headers(**token_options))
      expect(status).to eq 401
      expect(error).to eq "JWT token has been issued for another audience"
    end

    it "does not let a TokenError raised by the application become a 401" do
      allow(downstream).to receive(:call).and_raise(KeycloakApiRails::TokenError.expired("another token"))

      expect {
        call("/things", headers: authorization_headers(**token_options))
      }.to raise_error KeycloakApiRails::TokenError
    end
  end

  describe "when the token is rejected" do
    it "answers a 401 when no token is provided" do
      call("/things")

      expect(status).to eq 401
      expect(error).to eq "No JWT token provided"
    end

    it "answers a 401 when the token is expired" do
      call("/things", headers: authorization_headers(expires_at: Time.now - 3600))

      expect(status).to eq 401
      expect(error).to eq "JWT token is expired"
    end

    it "answers a 401 when the token is malformed" do
      call("/things", headers: { "HTTP_AUTHORIZATION" => "Bearer not-a-jwt" })

      expect(status).to eq 401
      expect(error).to eq "Wrong JWT Format"
    end

    it "answers a 401 when the token is signed by another key" do
      another_key = JSON::JWK.new(OpenSSL::PKey::RSA.generate(2048), kid: KeycloakApiRails::Testing::KEY_ID)
      token       = JSON::JWT.new("sub" => "x", "exp" => (Time.now + 3600).to_i).sign(another_key, :RS256).to_s

      call("/things", headers: { "HTTP_AUTHORIZATION" => "Bearer #{token}" })

      expect(status).to eq 401
      expect(error).to eq "Failed to verify JWT token"
    end

    # Used to raise a TypeError out of Time.at(nil), and answer a 500 instead of a 401.
    it "answers a 401 when the token carries no 'exp' claim" do
      token = JSON::JWT.new("sub" => "x").sign(KeycloakApiRails::Testing.signing_key, :RS256).to_s

      call("/things", headers: { "HTTP_AUTHORIZATION" => "Bearer #{token}" })

      expect(status).to eq 401
      expect(error).to eq "JWT token does not carry the mandatory claim 'exp'"
    end

    it "answers a 401 when the token carries an 'exp' claim that is not a number of seconds" do
      header        = Base64.urlsafe_encode64(JSON.generate("alg" => "RS256", "kid" => KeycloakApiRails::Testing::KEY_ID), padding: false)
      payload       = Base64.urlsafe_encode64(JSON.generate("sub" => "x", "exp" => nil), padding: false)
      signing_input = "#{header}.#{payload}"
      signature     = KeycloakApiRails::Testing.private_key.sign(OpenSSL::Digest::SHA256.new, signing_input)
      token         = "#{signing_input}.#{Base64.urlsafe_encode64(signature, padding: false)}"

      call("/things", headers: { "HTTP_AUTHORIZATION" => "Bearer #{token}" })

      expect(status).to eq 401
      expect(error).to eq "JWT token carries an invalid 'exp' claim: it must be a number of seconds since the Epoch"
    end

    it "does not call the downstream application" do
      call("/things")

      expect(@downstream_env).to be_nil
    end

    # RFC 6750: a request carrying no credentials is answered the bare challenge, with no error code.
    it "challenges a request that carries no token" do
      call("/things")

      expect(headers["www-authenticate"]).to eq "Bearer"
    end

    it "challenges a request whose token is not accepted, naming the error" do
      call("/things", headers: authorization_headers(expires_at: Time.now - 3600))

      expect(headers["www-authenticate"]).to eq 'Bearer error="invalid_token", error_description="JWT token is expired"'
    end

    it "quotes nothing that would break the challenge" do
      call("/things", headers: { "HTTP_AUTHORIZATION" => "Bearer not-a-token" })

      expect(headers["www-authenticate"].scan('"').size).to eq 4
    end

    it "only answers lowercase header names, as Rack 3 requires" do
      call("/things")

      expect(headers.keys).to eq headers.keys.map(&:downcase)
      expect(headers["content-type"]).to eq "application/json"
    end

    it "satisfies Rack::Lint" do
      skip "Rack::Lint checks the case of the header names from Rack 3 on" unless rack_3?

      expect { Rack::Lint.new(app).call(env_for("/things")) }.to_not raise_error
    end
  end

  describe "when no token can be verified at all" do
    let(:keycloak) { KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-public-keys") }

    before(:each) do
      keycloak.become_unreachable!
      KeycloakApiRails.public_key_resolver = keycloak
    end

    it "answers a 503 rather than letting the error escape as a 500" do
      call("/things", headers: authorization_headers)

      expect(status).to eq 503
      expect(error).to eq "Authentication is temporarily unavailable"
    end

    it "tells the client when to retry" do
      call("/things", headers: authorization_headers)

      expect(headers["retry-after"]).to eq KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS.to_s
    end

    it "only answers lowercase header names, as Rack 3 requires" do
      call("/things", headers: authorization_headers)

      expect(headers.keys).to eq headers.keys.map(&:downcase)
    end

    it "satisfies Rack::Lint" do
      skip "Rack::Lint checks the case of the header names from Rack 3 on" unless rack_3?

      expect {
        Rack::Lint.new(app).call(env_for("/things", headers: authorization_headers))
      }.to_not raise_error
    end

    it "does not call the downstream application" do
      call("/things", headers: authorization_headers)

      expect(@downstream_env).to be_nil
    end

    # The outage says nothing about a request that carries no token at all.
    it "still answers a 401 to a request carrying no token" do
      call("/things")

      expect(status).to eq 401
      expect(error).to eq "No JWT token provided"
    end

    it "still serves the paths that need no authentication" do
      KeycloakApiRails.config.skip_paths = { get: [%r{\A/health}] }

      call("/health/ready")

      expect(status).to eq 200
    end
  end

  describe "when the request does not need to be authenticated" do
    it "skips a path declared in 'skip_paths'" do
      KeycloakApiRails.config.skip_paths = { get: [%r{^/health}] }

      call("/health/ready")

      expect(status).to eq 200
      expect(@downstream_env).to_not be_nil
    end

    it "skips a path declared with an upcased HTTP method" do
      KeycloakApiRails.config.skip_paths = { "GET" => [%r{^/health}] }

      call("/health/ready")

      expect(status).to eq 200
    end

    it "skips a CORS preflight request" do
      call("/things", method: "OPTIONS", headers: { "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "GET" })

      expect(status).to eq 200
    end

    it "does not expose any claim to the downstream application" do
      KeycloakApiRails.config.skip_paths = { get: [%r{^/health}] }

      call("/health/ready")

      expect(KeycloakApiRails::Helper.current_user_id(@downstream_env)).to be_nil
    end
  end

  describe "when 'skip_paths' anchors a path with '^' or '$'" do
    def call_path(path)
      @response = app.call(env_for("/things").merge("PATH_INFO" => path))
    end

    it "warns that those anchors match a line, not the path" do
      logger = ::Logger.new(warnings = StringIO.new)
      KeycloakApiRails.config.logger    = logger
      KeycloakApiRails.config.skip_paths = { get: [%r{^/health}] }

      call("/health/ready")

      expect(warnings.string).to include "skip_paths[:get]"
      expect(warnings.string).to include "Anchor with"
    end

    it "does not warn about a path anchored with '\\A' and '\\z'" do
      logger = ::Logger.new(warnings = StringIO.new)
      KeycloakApiRails.config.logger    = logger
      KeycloakApiRails.config.skip_paths = { get: [%r{\A/health}] }

      call("/health/ready")

      expect(warnings.string).to_not include "Anchor with"
    end

    it "does not read the '^' of a character class as an anchor" do
      logger = ::Logger.new(warnings = StringIO.new)
      KeycloakApiRails.config.logger    = logger
      KeycloakApiRails.config.skip_paths = { get: [%r{\A/health/[^/]+\z}] }

      call("/health/ready")

      expect(warnings.string).to_not include "Anchor with"
    end

    it "opens a path it was never meant to open" do
      KeycloakApiRails.config.skip_paths = { get: [%r{^/health}] }

      call_path("/private\n/health")

      expect(status).to eq 200
    end

    it "keeps authenticating it once anchored with '\\A'" do
      KeycloakApiRails.config.skip_paths = { get: [%r{\A/health}] }

      call_path("/private\n/health")

      expect(status).to eq 401
    end
  end

  # 'validate!' rejects such a configuration when a Rails application boots. A Rack application
  # running without Rails never calls it, so the paths have to keep being authenticated here.
  describe "when 'skip_paths' declares its paths as Strings" do
    before(:each) do
      KeycloakApiRails.config.skip_paths = { get: ["/health/db"] }
    end

    it "keeps authenticating the paths that were never declared" do
      ["/", "/h", "/health", "/db", "/things"].each do |path|
        call(path)

        expect(status).to eq 401
      end
    end

    it "keeps authenticating the declared path itself" do
      call("/health/db")

      expect(status).to eq 401
    end

    it "warns that the declared paths are ignored" do
      logger = ::Logger.new(warnings = StringIO.new)
      KeycloakApiRails.config.logger = logger

      call("/health/db")

      expect(warnings.string).to include "skip_paths[:get]"
      expect(warnings.string).to include "keep being authenticated"
    end
  end

  describe "when the request is authenticated" do
    it "satisfies Rack::Lint" do
      skip "Rack::Lint checks the case of the header names from Rack 3 on" unless rack_3?

      expect {
        Rack::Lint.new(app).call(env_for("/things", headers: authorization_headers))
      }.to_not raise_error
    end
  end
end
