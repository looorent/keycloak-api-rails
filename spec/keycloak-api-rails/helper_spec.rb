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
