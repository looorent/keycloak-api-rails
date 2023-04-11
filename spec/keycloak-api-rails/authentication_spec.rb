require "spec_helper"

describe Keycloak::Authentication do
  class ExampleController < ActionController::Base
    include Keycloak::Authentication
    # Mark protected methods public so they may be called in tests
    public(*Keycloak::Authentication.protected_instance_methods)
  end

  let(:controller) { ExampleController.new }
  let(:token) { 'keycloak_valid_token'}
  let(:headers) do
    {
      'REQUEST_METHOD' => :get,
      'REQUEST_URI' => 'http://www.an-url.io',
      'HTTP_AUTHORIZATION' => "Bearer #{token}"
    }
  end

  describe "#keycloak_authenticate" do
    before do
      # Mock request object because we aren't using real request spec
      allow(controller).to receive(:request).and_return(double("request", env: headers ))
    end

    it "it authenticates with request header" do
      expect_any_instance_of(Keycloak::Service).to receive(:decode_and_verify).with(token).and_return("A User")
      expect(controller).to receive(:authentication_succeeded)
      controller.keycloak_authenticate
    end
  end
end
