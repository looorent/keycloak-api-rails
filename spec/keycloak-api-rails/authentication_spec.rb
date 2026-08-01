require "spec_helper"

describe KeycloakApiRails::Authentication do
  class ExampleController < ActionController::Base
    include KeycloakApiRails::Authentication
    # Mark protected methods public so they may be called in tests
    public(*KeycloakApiRails::Authentication.protected_instance_methods)
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

  describe "when included" do
    it "declares keycloak_authenticate as a helper method when the base class supports helpers" do
      declared_helper_methods = []
      base = Class.new do
        define_singleton_method(:helper_method) { |*names| declared_helper_methods.concat(names) }
      end

      base.include(KeycloakApiRails::Authentication)

      expect(declared_helper_methods).to eq [:keycloak_authenticate]
    end

    it "declares the helper method on a real controller" do
      expect(ExampleController._helper_methods).to include :keycloak_authenticate
    end

    it "does not fail when the base class does not support helpers" do
      expect {
        Class.new.include(KeycloakApiRails::Authentication)
      }.to_not raise_error
    end

    it "exposes its methods as protected instance methods" do
      expect(KeycloakApiRails::Authentication.protected_instance_methods).to match_array %i[
        keycloak_authenticate
        authentication_failed
        authentication_succeeded
      ]
    end

    it "does not add any public method to the including class" do
      base = Class.new.include(KeycloakApiRails::Authentication)

      expect(base.public_instance_methods).to_not include :keycloak_authenticate
      expect(base.protected_instance_methods).to include :keycloak_authenticate
    end
  end

  describe "#keycloak_authenticate" do
    before do
      # Mock request object because we aren't using real request spec
      allow(controller).to receive(:request).and_return(double("request", env: headers ))
      @logger = KeycloakApiRails.config.logger
      KeycloakApiRails.config.logger = ::Logger.new(File::NULL)
    end

    after do
      KeycloakApiRails.config.logger = @logger
    end

    it "it authenticates with request header" do
      expect_any_instance_of(KeycloakApiRails::Service).to receive(:decode_and_verify).with(token).and_return("A User")
      expect(controller).to receive(:authentication_succeeded)
      controller.keycloak_authenticate
    end
  end
end
