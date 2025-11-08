RSpec.describe KeycloakApiRails::Service do

  let(:public_key_cache_ttl)  { 86400 }
  let(:server_url)            { "whatever:8080" }
  let(:realm_id)              { "pouet" }
  let!(:resolver)             { KeycloakApiRails::PublicKeyCachedResolver.new(server_url, realm_id, public_key_cache_ttl) }

  before(:each) do
    resolver.instance_variable_set(:@resolver, KeycloakApiRails::PublicKeyResolverStub.new)
    now = Time.local(2018, 1, 9, 12, 0, 0)
    Timecop.freeze(now)
  end

  after(:each) do
    Timecop.return
  end

  describe "#find_public_key" do
    context "when there is no public key in cache yet" do
      before(:each) do
        @public_key = resolver.find_public_keys
      end

      it "returns a valid public key" do
        expect(@public_key).to_not be_nil
      end

      it "sets the current time to the resolver" do
        expect(resolver.cached_public_key_retrieved_at).to eq Time.now
      end
    end

    context "when there is already a public key in cache" do
      before(:each) do
        @first_public_key                     = resolver.find_public_keys
        @first_cached_public_key_retrieved_at = resolver.cached_public_key_retrieved_at
      end

      context "and no need to refresh it" do
        before(:each) do
          Timecop.freeze(Time.now + public_key_cache_ttl.seconds - 10.seconds)
          @second_public_key                     = resolver.find_public_keys
          @second_cached_public_key_retrieved_at = resolver.cached_public_key_retrieved_at
        end

        it "returns a valid public key" do
          expect(@second_public_key).to_not be_nil
        end

        it "does not refresh the public key" do
          expect(@second_public_key).to eq @first_public_key
        end

        it "does not refresh the public key retrieval time" do
          expect(@first_cached_public_key_retrieved_at).to eq @second_cached_public_key_retrieved_at
        end
      end

      context "and its TTL has expired" do
        before(:each) do
          Timecop.freeze(Time.now + public_key_cache_ttl.seconds + 10.seconds)
          @second_public_key                     = resolver.find_public_keys
          @second_cached_public_key_retrieved_at = resolver.cached_public_key_retrieved_at
        end

        it "returns a valid public key" do
          expect(@second_public_key).to_not be_nil
        end

        it "refreshes the public key" do
          expect(@second_public_key).to_not eq @first_public_key
        end

        it "refreshes the public key retrieval time" do
          expect(@first_cached_public_key_retrieved_at).to_not eq @second_cached_public_key_retrieved_at
        end
      end
    end
  end
end
