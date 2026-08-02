require "spec_helper"
require "rack/mock"
require_relative "keycloak_helper"

RSpec.describe "Integration with real Keycloak server" do
  before(:all) do
    KeycloakHelper.start_keycloak
  end

  after(:all) do
    KeycloakHelper.stop_keycloak
  end

  before(:each) do
    # Reset configuration to use the real server
    KeycloakApiRails.configure do |config|
      config.server_url = KeycloakHelper::KEYCLOAK_URL
      config.realm_id = KeycloakHelper::REALM_NAME
      config.skip_paths = { get: [/^\/skip/] }
    end
    # Ensure public key resolver is the real one, not stubbed
    KeycloakApiRails.public_key_resolver = nil
  end

  let(:app) do
    ->(env) { [200, env, ["OK"]] }
  end

  let(:middleware) do
    KeycloakApiRails::Middleware.new(app)
  end

  let(:request) { Rack::MockRequest.new(middleware) }

  it "successfully validates a token fetched from a real Keycloak >= 19" do
    token = KeycloakHelper.get_user_token
    expect(token).not_to be_nil

    response = request.get("/", "HTTP_AUTHORIZATION" => "Bearer #{token}")

    expect(response.status).to eq(200)
    # the middleware adds keycloak env variables if successful
    # env vars in rack are uppercase, but the gem sets specific keys
    # let's check current_user_id
    env = response.headers
    user_id = KeycloakApiRails::Helper.current_user_id(env)
    expect(user_id).not_to be_nil
  end

  it "rejects requests without token" do
    response = request.get("/")
    expect(response.status).to eq(401)
  end

  it "accepts requests on skipped paths without token" do
    response = request.get("/skip")
    expect(response.status).to eq(200)
  end

  it "rejects requests with invalid token" do
    response = request.get("/", "HTTP_AUTHORIZATION" => "Bearer invalid.token.here")
    expect(response.status).to eq(401)
  end
end
