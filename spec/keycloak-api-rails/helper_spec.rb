RSpec.describe KeycloakApiRails::Helper do
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
