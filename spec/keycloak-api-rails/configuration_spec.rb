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
    end

    it "exposes the logger through KeycloakApiRails.logger" do
      expect(KeycloakApiRails.logger).to be KeycloakApiRails.config.logger
    end
  end
end
