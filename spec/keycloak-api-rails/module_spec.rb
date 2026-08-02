require "keycloak-api-rails/testing"

RSpec.describe KeycloakApiRails do
  describe "the memoized objects" do
    before(:each) do
      KeycloakApiRails.load_configuration
      KeycloakApiRails.config.logger     = ::Logger.new(File::NULL)
      KeycloakApiRails.config.server_url = "https://keycloak.example.org"
      KeycloakApiRails.config.realm_id   = "a-realm"
      # Also discards the memoized service, so that the examples below build it themselves.
      KeycloakApiRails::Testing.stub_public_keys!
    end

    after(:each) do
      KeycloakApiRails.public_key_resolver = nil
      KeycloakApiRails.load_configuration
    end

    # Widens the window in which two threads can both find the memoization empty.
    def count_and_slow_down(klass)
      built = 0
      counter = Mutex.new
      allow(klass).to receive(:new).and_wrap_original do |original, *arguments|
        counter.synchronize { built += 1 }
        sleep 0.05
        original.call(*arguments)
      end
      built_reader = -> { built }
      [built_reader, counter]
    end

    def concurrently(thread_count, &block)
      Array.new(thread_count) { Thread.new(&block) }.map(&:value)
    end

    it "builds a single service, whichever thread asks for it first" do
      built, = count_and_slow_down(KeycloakApiRails::Service)

      services = concurrently(10) { KeycloakApiRails.service }

      expect(built.call).to eq 1
      expect(services.uniq.size).to eq 1
    end

    it "builds a single public key resolver" do
      KeycloakApiRails.public_key_resolver = nil
      built, = count_and_slow_down(KeycloakApiRails::PublicKeyCachedResolver)

      resolvers = concurrently(10) { KeycloakApiRails.public_key_resolver }

      expect(built.call).to eq 1
      expect(resolvers.uniq.size).to eq 1
    end

    it "builds a single HTTP client" do
      KeycloakApiRails.instance_variable_set(:@http_client, nil)
      built, = count_and_slow_down(KeycloakApiRails::HTTPClient)

      clients = concurrently(10) { KeycloakApiRails.http_client }

      expect(built.call).to eq 1
      expect(clients.uniq.size).to eq 1
    end
  end

  describe "#configure" do
    before(:each) do
      KeycloakApiRails.load_configuration
      KeycloakApiRails.config.logger     = ::Logger.new(File::NULL)
      KeycloakApiRails.config.server_url = "https://keycloak.example.org"
      KeycloakApiRails.config.realm_id   = "a-realm"
    end

    after(:each) do
      KeycloakApiRails.public_key_resolver = nil
      KeycloakApiRails.load_configuration
    end

    it "discards the service it had memoized" do
      KeycloakApiRails::Testing.stub_public_keys!
      service = KeycloakApiRails.service

      KeycloakApiRails.configure { |config| config.expected_audience = "my-api" }

      expect(KeycloakApiRails.service).to_not be service
    end

    it "discards the HTTP client it had memoized" do
      client = KeycloakApiRails.http_client

      KeycloakApiRails.configure { |config| config.http_read_timeout = 2 }

      expect(KeycloakApiRails.http_client).to_not be client
    end

    it "discards the public key resolver it had memoized" do
      resolver = KeycloakApiRails.public_key_resolver

      KeycloakApiRails.configure { |config| config.realm_id = "another-realm" }

      expect(KeycloakApiRails.public_key_resolver).to_not be resolver
    end

    # Discarding it would uninstall the resolver of "keycloak-api-rails/testing" on the first
    # example that configures anything.
    it "keeps the public key resolver that has been assigned explicitly" do
      KeycloakApiRails::Testing.stub_public_keys!
      resolver = KeycloakApiRails.public_key_resolver

      KeycloakApiRails.configure { |config| config.expected_audience = "my-api" }

      expect(KeycloakApiRails.public_key_resolver).to be resolver
    end

    it "memoizes the regular resolver again once the override is withdrawn" do
      KeycloakApiRails::Testing.stub_public_keys!
      KeycloakApiRails.public_key_resolver = nil

      resolver = KeycloakApiRails.public_key_resolver
      KeycloakApiRails.configure { |config| config.realm_id = "another-realm" }

      expect(resolver).to be_a KeycloakApiRails::PublicKeyCachedResolver
      expect(KeycloakApiRails.public_key_resolver).to_not be resolver
    end
  end

  describe "KeycloakApiRails::Testing" do
    before(:each) do
      %i[@private_key @signing_key @public_keys].each do |name|
        KeycloakApiRails::Testing.instance_variable_set(name, nil)
      end
    end

    after(:each) do
      KeycloakApiRails::Testing.stub_public_keys!
    end
    it "generates a single key pair, whichever thread forges a token first" do
      keys = Array.new(8) { Thread.new { [KeycloakApiRails::Testing.signing_key, KeycloakApiRails::Testing.public_keys] } }.map(&:value)

      expect(keys.map(&:first).uniq.size).to eq 1
      expect(keys.map(&:last).uniq.size).to eq 1
    end
  end
end
