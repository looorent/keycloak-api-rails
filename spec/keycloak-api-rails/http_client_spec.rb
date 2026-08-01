RSpec.describe KeycloakApiRails::HTTPClient do

  let(:configuration) do
    KeycloakApiRails::Configuration.new.tap do |configuration|
      configuration.server_url        = "https://keycloak.example.org"
      configuration.realm_id          = "a-realm"
      configuration.http_open_timeout = 3
      configuration.http_read_timeout = 4
    end
  end

  let(:logger) { ::Logger.new(File::NULL) }
  let(:client) { KeycloakApiRails::HTTPClient.new(configuration, logger) }

  def stub_response(response)
    allow(Net::HTTP).to receive(:start) do |*_args, **options, &_block|
      @start_options = options
      response
    end
  end

  def response(klass, code, body)
    klass.new("1.1", code, "").tap { |response| allow(response).to receive(:body).and_return(body) }
  end

  describe "#get" do
    context "when Keycloak answers successfully" do
      before(:each) do
        stub_response(response(Net::HTTPOK, "200", '{"keys":[{"kid":"a-key"}]}'))
      end

      it "returns the parsed payload" do
        expect(client.get("a-realm", "protocol/openid-connect/certs")).to eq({ "keys" => [{ "kid" => "a-key" }] })
      end

      it "builds the url from the server url and the realm" do
        expect(Net::HTTP).to receive(:start).with("keycloak.example.org", 443, any_args)

        client.get("a-realm", "protocol/openid-connect/certs")
      end

      it "applies the configured timeouts" do
        client.get("a-realm", "protocol/openid-connect/certs")

        expect(@start_options[:open_timeout]).to eq 3
        expect(@start_options[:read_timeout]).to eq 4
      end
    end

    context "when Keycloak answers an error" do
      before(:each) do
        stub_response(response(Net::HTTPInternalServerError, "500", "something went wrong"))
      end

      it "raises an HTTPError carrying the status" do
        expect {
          client.get("a-realm", "protocol/openid-connect/certs")
        }.to raise_error(KeycloakApiRails::HTTPError, /500/) { |error| expect(error.status).to eq "500" }
      end
    end

    context "when Keycloak cannot be reached" do
      before(:each) do
        allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      end

      it "raises an HTTPError" do
        expect {
          client.get("a-realm", "protocol/openid-connect/certs")
        }.to raise_error KeycloakApiRails::HTTPError
      end
    end

    context "when Keycloak answers a malformed payload" do
      before(:each) do
        stub_response(response(Net::HTTPOK, "200", "<html>not json</html>"))
      end

      it "raises an HTTPError" do
        expect {
          client.get("a-realm", "protocol/openid-connect/certs")
        }.to raise_error KeycloakApiRails::HTTPError
      end
    end

    context "when the server is not configured" do
      before(:each) do
        configuration.server_url = nil
      end

      it "raises an InvalidConfigurationError naming the missing option" do
        expect {
          client.get("a-realm", "protocol/openid-connect/certs")
        }.to raise_error KeycloakApiRails::InvalidConfigurationError, /server_url/
      end
    end
  end
end
