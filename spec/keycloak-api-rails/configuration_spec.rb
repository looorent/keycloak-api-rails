RSpec.describe KeycloakApiRails::Configuration do

  # Every attribute that used to be declared through ActiveSupport's `config_accessor`.
  let(:attribute_names) do
    %i[
      server_url
      realm_id
      skip_paths
      opt_in
      token_expiration_tolerance_in_seconds
      public_key_cache_ttl
      custom_attributes
      logger
      ca_certificate_file
      expected_audience
      expected_token_type
      verify_not_before
      allow_token_in_query_string
      http_open_timeout
      http_read_timeout
    ]
  end

  describe "attributes" do
    let(:configuration) { KeycloakApiRails::Configuration.new }

    it "exposes a reader and a writer for each attribute" do
      attribute_names.each do |name|
        expect(configuration).to respond_to name
        expect(configuration).to respond_to "#{name}="
      end
    end

    it "returns nil for each attribute that has not been assigned" do
      attribute_names.each do |name|
        expect(configuration.public_send(name)).to be_nil
      end
    end

    it "returns the value that has been assigned" do
      attribute_names.each do |name|
        configuration.public_send("#{name}=", "a value for #{name}")
        expect(configuration.public_send(name)).to eq "a value for #{name}"
      end
    end

    it "does not respond to an unknown attribute" do
      expect(configuration).to_not respond_to :not_a_configuration_attribute
      expect {
        configuration.not_a_configuration_attribute
      }.to raise_error NoMethodError
    end
  end

  describe "#configure" do
    after(:each) do
      KeycloakApiRails.load_configuration
    end

    it "yields the configuration" do
      expect { |block| KeycloakApiRails.configure(&block) }.to yield_with_args KeycloakApiRails::Configuration
    end

    it "keeps the values assigned within the block" do
      KeycloakApiRails.configure do |config|
        config.server_url          = "http://keycloak:8080"
        config.realm_id            = "a-realm"
        config.ca_certificate_file = "/etc/ssl/a-certificate.pem"
      end

      expect(KeycloakApiRails.config.server_url).to eq "http://keycloak:8080"
      expect(KeycloakApiRails.config.realm_id).to eq "a-realm"
      expect(KeycloakApiRails.config.ca_certificate_file).to eq "/etc/ssl/a-certificate.pem"
    end

    it "always returns the same configuration instance" do
      expect(KeycloakApiRails.config).to be KeycloakApiRails.config
    end
  end

  describe "#load_configuration" do
    before(:each) do
      KeycloakApiRails.load_configuration
    end

    after(:each) do
      KeycloakApiRails.load_configuration
    end

    it "applies the documented default values" do
      config = KeycloakApiRails.config

      expect(config.server_url).to be_nil
      expect(config.realm_id).to be_nil
      expect(config.logger).to be_a ::Logger
      expect(config.skip_paths).to eq({})
      expect(config.opt_in).to be false
      expect(config.token_expiration_tolerance_in_seconds).to eq 10
      expect(config.public_key_cache_ttl).to eq 86400
      expect(config.custom_attributes).to eq []
      expect(config.ca_certificate_file).to be_nil
      expect(config.expected_audience).to be_nil
      expect(config.expected_token_type).to be_nil
      expect(config.verify_not_before).to be false
      expect(config.allow_token_in_query_string).to be false
      expect(config.http_open_timeout).to eq 5
      expect(config.http_read_timeout).to eq 5
    end

    it "exposes the logger through KeycloakApiRails.logger" do
      expect(KeycloakApiRails.logger).to be KeycloakApiRails.config.logger
    end
  end

  # Called by the railtie once the application initializers have run, so that a mistake in
  # 'config/initializers/keycloak.rb' fails at boot rather than on the first request.
  describe "#validate!" do
    let(:configuration) do
      KeycloakApiRails.load_configuration
      KeycloakApiRails.config
    end

    after(:each) do
      KeycloakApiRails.load_configuration
    end

    def expect_rejection(message)
      expect { configuration.validate! }.to raise_error KeycloakApiRails::InvalidConfigurationError, message
    end

    it "accepts the default configuration" do
      expect(configuration.validate!).to be true
    end

    it "accepts a fully assigned configuration" do
      configuration.server_url          = "https://keycloak.example.org"
      configuration.realm_id            = "a-realm"
      configuration.skip_paths          = { get: [%r{^/health}], post: [%r{^/message}] }
      configuration.opt_in              = true
      configuration.custom_attributes   = ["tenant_id"]
      configuration.expected_audience   = ["my-api"]
      configuration.expected_token_type = "Bearer"
      configuration.verify_not_before   = true
      configuration.allow_token_in_query_string = true

      expect(configuration.validate!).to be true
    end

    it "rejects a 'server_url' that is not a String" do
      configuration.server_url = URI("https://keycloak.example.org")

      expect_rejection(/'server_url' must be a String or nil/)
    end

    it "rejects a logger that cannot log" do
      configuration.logger = "not a logger"

      expect_rejection(/'logger' must respond to/)
    end

    it "rejects a non-boolean 'opt_in'" do
      configuration.opt_in = "true"

      expect_rejection(/'opt_in' must be true or false/)
    end

    it "rejects a non-boolean 'allow_token_in_query_string'" do
      configuration.allow_token_in_query_string = "yes"

      expect_rejection(/'allow_token_in_query_string' must be true or false/)
    end

    it "rejects 'skip_paths' that is not a Hash" do
      configuration.skip_paths = [%r{^/health}]

      expect_rejection(/'skip_paths' must be a Hash/)
    end

    it "rejects 'skip_paths' whose values are not arrays of regexps" do
      configuration.skip_paths = { get: %r{^/health} }

      expect_rejection(/'skip_paths\[:get\]' must be an Array of regexps/)
    end

    it "rejects 'custom_attributes' that is not an Array" do
      configuration.custom_attributes = "tenant_id"

      expect_rejection(/'custom_attributes' must be an Array/)
    end

    it "rejects a 'public_key_cache_ttl' that is not a positive number" do
      configuration.public_key_cache_ttl = 0

      expect_rejection(/'public_key_cache_ttl' must be a positive number/)
    end

    it "rejects a negative 'token_expiration_tolerance_in_seconds'" do
      configuration.token_expiration_tolerance_in_seconds = -1

      expect_rejection(/'token_expiration_tolerance_in_seconds' must be a number/)
    end

    it "rejects a 'http_read_timeout' that is not a positive number" do
      configuration.http_read_timeout = "5"

      expect_rejection(/'http_read_timeout' must be a positive number/)
    end

    it "rejects an 'expected_audience' that is neither a String nor an Array of Strings" do
      configuration.expected_audience = { audience: "my-api" }

      expect_rejection(/'expected_audience' must be a String, an Array of Strings, or nil/)
    end

    it "rejects an 'expected_audience' Array holding something else than Strings" do
      configuration.expected_audience = ["my-api", :another_api]

      expect_rejection(/'expected_audience' must only contain Strings/)
    end

    it "rejects a 'ca_certificate_file' that cannot be read" do
      configuration.ca_certificate_file = "/nowhere/no-such-certificate.pem"

      expect_rejection(/'ca_certificate_file' must be the path of a readable file/)
    end

    it "reports every problem at once" do
      configuration.opt_in            = "true"
      configuration.custom_attributes = "tenant_id"

      expect_rejection(/'opt_in'.*'custom_attributes'/m)
    end
  end

  # 'server_url' and 'realm_id' are only needed to download the public keys: they are checked when
  # that download is about to happen, so that an application replacing the resolver -- through
  # "keycloak-api-rails/testing" -- keeps working without them.
  describe "#validate_server!" do
    let(:configuration) { KeycloakApiRails::Configuration.new }

    it "accepts a configured server" do
      configuration.server_url = "https://keycloak.example.org"
      configuration.realm_id   = "a-realm"

      expect(configuration.validate_server!).to be true
      expect(configuration.server_configured?).to be true
    end

    it "rejects a missing 'server_url'" do
      configuration.realm_id = "a-realm"

      expect {
        configuration.validate_server!
      }.to raise_error KeycloakApiRails::InvalidConfigurationError, /'server_url' must be configured/
    end

    it "rejects a blank 'realm_id'" do
      configuration.server_url = "https://keycloak.example.org"
      configuration.realm_id   = "   "

      expect {
        configuration.validate_server!
      }.to raise_error KeycloakApiRails::InvalidConfigurationError, /'realm_id' must be configured/
    end

    it "is not satisfied by an unconfigured server" do
      expect(configuration.server_configured?).to be false
    end
  end
end
