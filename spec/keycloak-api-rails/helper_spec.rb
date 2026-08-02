RSpec.describe KeycloakApiRails::Helper do
  describe "#read_token_from_query_string" do

    subject { KeycloakApiRails::Helper.read_token_from_query_string(uri) }

    context "when the uri is nil" do
      let(:uri) { nil }
      it "returns an empty token" do
        expect(subject).to eq ""
      end
    end

    context "when the uri is empty" do
      let(:uri) { "" }
      it "returns an empty token" do
        expect(subject).to eq ""
      end
    end

    context "when the uri only contains whitespaces" do
      let(:uri) { "   " }
      it "returns an empty token" do
        expect(subject).to eq ""
      end
    end

    context "when the uri has no query string" do
      let(:uri) { "http://www.an-url.io/health" }
      it "returns no token" do
        expect(subject).to be_nil
      end
    end

    context "when the uri has a query string but no token" do
      let(:uri) { "http://www.an-url.io/health?firstName=ouioui" }
      it "returns no token" do
        expect(subject).to be_nil
      end
    end

    context "when the uri has a token in the query string" do
      let(:uri) { "http://www.an-url.io/health?authorizationToken=aToken" }
      it "returns the token" do
        expect(subject).to eq "aToken"
      end
    end

    context "when the uri has a token among other query string parameters" do
      let(:uri) { "http://www.an-url.io/health?firstName=ouioui&authorizationToken=aToken&lastName=nonnon" }
      it "returns the token" do
        expect(subject).to eq "aToken"
      end
    end

    context "when the uri has an empty token in the query string" do
      let(:uri) { "http://www.an-url.io/health?authorizationToken=" }
      it "returns an empty token" do
        expect(subject).to eq ""
      end
    end
  end

  describe "#read_token_from_headers" do
    def read(authorization)
      KeycloakApiRails::Helper.read_token_from_headers("HTTP_AUTHORIZATION" => authorization)
    end

    it "reads the token of a Bearer header" do
      expect(read("Bearer aToken")).to eq "aToken"
    end

    it "reads the token whatever the case of the scheme (RFC 7235)" do
      expect(read("bearer aToken")).to eq "aToken"
      expect(read("BEARER aToken")).to eq "aToken"
      expect(read("BeArEr aToken")).to eq "aToken"
    end

    it "reads the token whatever the number of spaces following the scheme" do
      expect(read("Bearer   aToken")).to eq "aToken"
      expect(read("Bearer\taToken")).to eq "aToken"
    end

    it "only strips the scheme at the very beginning of the value" do
      expect(read("Bearer aToken\nBearer anotherToken")).to eq "aToken\nBearer anotherToken"
    end

    it "leaves a value carrying another scheme untouched" do
      expect(read("Basic dXNlcjpwYXNzd29yZA==")).to eq "Basic dXNlcjpwYXNzd29yZA=="
    end

    it "returns an empty token when the header is absent" do
      expect(KeycloakApiRails::Helper.read_token_from_headers({})).to eq ""
    end
  end

  describe "#request_uri" do
    it "returns the 'REQUEST_URI' the server provided" do
      expect(KeycloakApiRails::Helper.request_uri("REQUEST_URI" => "/health?a=1")).to eq "/health?a=1"
    end

    it "rebuilds the uri when the environment carries no 'REQUEST_URI'" do
      expect(KeycloakApiRails::Helper.request_uri("PATH_INFO" => "/health", "QUERY_STRING" => "a=1")).to eq "/health?a=1"
    end

    it "rebuilds the uri of a request that has no query string" do
      expect(KeycloakApiRails::Helper.request_uri("PATH_INFO" => "/health", "QUERY_STRING" => "")).to eq "/health"
      expect(KeycloakApiRails::Helper.request_uri("PATH_INFO" => "/health")).to eq "/health"
    end
  end

  describe "#assign_current_user_custom_attributes" do
    let(:token) { { "sub" => "a-user", "tenant_id" => 42, "department" => "sales" } }

    def attributes_declared_as(attribute_names)
      env = {}
      KeycloakApiRails::Helper.assign_current_user_custom_attributes(env, token, attribute_names)
      KeycloakApiRails::Helper.current_user_custom_attributes(env)
    end

    it "reads the claims declared as Strings" do
      expect(attributes_declared_as(["tenant_id"])).to eq({ "tenant_id" => 42 })
    end

    it "reads the claims declared as Symbols" do
      expect(attributes_declared_as([:tenant_id])).to eq({ "tenant_id" => 42 })
    end

    it "reads the claims of a declaration mixing both" do
      expect(attributes_declared_as([:tenant_id, "department"])).to eq({ "tenant_id" => 42, "department" => "sales" })
    end

    it "reads no claim when none is declared" do
      expect(attributes_declared_as([])).to eq({})
      expect(attributes_declared_as(nil)).to eq({})
    end

    it "reads no claim the token does not carry" do
      expect(attributes_declared_as([:not_a_claim_of_this_token])).to eq({})
    end
  end

  describe "#create_url_with_token" do

    let(:uri)   { "http://www.an-url.io" }
    let(:token) { "aToken" }

    before(:each) do
      @url_with_token = KeycloakApiRails::Helper.create_url_with_token(uri, token)
    end

    context "when the uri has no query string yet" do
      it "returns an url with the provided token" do
        expect(@url_with_token).to eq "#{uri}?authorizationToken=#{token}"
      end
    end

    context "when the uri already has no query strings" do
      context "but no token yet" do
        let(:uri)   { "http://www.an-url.io?firstName=ouioui&lastName=nonnon" }
        it "returns an url with all the query string and the token" do
          expect(@url_with_token).to eq "#{uri}&authorizationToken=#{token}"
        end
      end

      context "including a token" do
        let(:uri)   { "http://www.an-url.io?authorizationToken=ouioui&lastName=nonnon" }
        it "returns an url with all the query string and the new token" do
          expect(@url_with_token).to eq "http://www.an-url.io?lastName=nonnon&authorizationToken=#{token}"
        end
      end
    end
  end
end
