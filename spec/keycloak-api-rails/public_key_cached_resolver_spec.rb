RSpec.describe KeycloakApiRails::PublicKeyCachedResolver do

  let(:public_key_cache_ttl)  { 86400 }
  let(:server_url)            { "whatever:8080" }
  let(:realm_id)              { "pouet" }

  before(:each) do
    now = Time.local(2018, 1, 9, 12, 0, 0)
    Timecop.freeze(now)
  end

  after(:each) do
    Timecop.return
  end

  describe "#find_public_key" do
    let!(:resolver) { KeycloakApiRails::PublicKeyCachedResolver.new(server_url, realm_id, public_key_cache_ttl) }

    before(:each) do
      resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, KeycloakApiRails::PublicKeyResolverStub.new)
    end

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

    context "when Keycloak has become unreachable" do
      let(:keycloak) { KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-public-keys") }

      before(:each) do
        resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, keycloak)
      end

      context "and public keys have already been retrieved" do
        before(:each) do
          resolver.find_public_keys
          keycloak.become_unreachable!
          Timecop.freeze(Time.now + public_key_cache_ttl.seconds + 10.seconds)
        end

        it "keeps serving the keys retrieved last" do
          expect(resolver.find_public_keys).to eq "the-public-keys"
        end

        it "keeps the time at which those keys were retrieved" do
          retrieved_at = resolver.cached_public_key_retrieved_at
          resolver.find_public_keys

          expect(resolver.cached_public_key_retrieved_at).to eq retrieved_at
        end

        it "does not call Keycloak again on every request" do
          calls_before_failing = keycloak.calls
          5.times { resolver.find_public_keys }

          expect(keycloak.calls).to eq calls_before_failing + 1
        end

        it "calls Keycloak again once the retry delay has elapsed" do
          resolver.find_public_keys
          calls_after_first_failure = keycloak.calls

          Timecop.freeze(Time.now + KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS + 1)
          resolver.find_public_keys

          expect(keycloak.calls).to eq calls_after_first_failure + 1
        end

        it "serves the fresh keys again once Keycloak answers" do
          resolver.find_public_keys
          Timecop.freeze(Time.now + KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS + 1)
          resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-new-public-keys"))

          expect(resolver.find_public_keys).to eq "the-new-public-keys"
        end
      end

      context "and no public key has ever been retrieved" do
        before(:each) do
          keycloak.become_unreachable!
        end

        # Answering nil would let the service decode a token without verifying its signature.
        it "propagates the error rather than answering without a key" do
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError
        end

        it "does not call Keycloak again on every request" do
          5.times { expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError }

          expect(keycloak.calls).to eq 1
        end

        it "keeps raising the error of the last attempt while it does not call Keycloak" do
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError, "Keycloak is unreachable"
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError, "Keycloak is unreachable"
        end

        it "calls Keycloak again once the retry delay has elapsed" do
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError

          Timecop.freeze(Time.now + KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS + 1)
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError

          expect(keycloak.calls).to eq 2
        end

        it "serves the keys again once Keycloak answers" do
          expect { resolver.find_public_keys }.to raise_error KeycloakApiRails::HTTPError

          Timecop.freeze(Time.now + KeycloakApiRails::PublicKeyCachedResolver::FAILED_REFRESH_RETRY_DELAY_IN_SECONDS + 1)
          resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-public-keys"))

          expect(resolver.find_public_keys).to eq "the-public-keys"
        end

        it "downloads the keys once when several threads ask at the same time" do
          slow = KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-public-keys", delay: 0.05)
          slow.become_unreachable!
          resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, slow)

          Array.new(10) { Thread.new { resolver.find_public_keys rescue nil } }.map(&:join)

          expect(slow.calls).to eq 1
        end
      end
    end

    context "when several threads need the public keys at once" do
      let(:keycloak) { KeycloakApiRails::ControllablePublicKeyResolverStub.new("the-public-keys", delay: 0.05) }

      before(:each) do
        resolver.send(:cache_for, "pouet").instance_variable_set(:@resolver, keycloak)
      end

      def resolve_concurrently(thread_count)
        Array.new(thread_count) { Thread.new { resolver.find_public_keys } }.map(&:value)
      end

      it "downloads the public keys once" do
        expect(resolve_concurrently(10)).to all eq "the-public-keys"
        expect(keycloak.calls).to eq 1
      end

      it "downloads them once again when the cache outlives its TTL" do
        resolve_concurrently(10)
        Timecop.freeze(Time.now + public_key_cache_ttl.seconds + 10.seconds)

        expect(resolve_concurrently(10)).to all eq "the-public-keys"
        expect(keycloak.calls).to eq 2
      end
    end
  end

  describe "the realms it caches" do
    let(:keycloak) { KeycloakApiRails::HTTPClientStub.new }
    let(:logger)   { instance_double(Logger, warn: nil) }

    def resolver_for(configured_realm_id)
      KeycloakApiRails::PublicKeyCachedResolver.new(keycloak, configured_realm_id, public_key_cache_ttl, logger)
    end

    context "when a single realm is configured" do
      let(:resolver) { resolver_for("a-realm") }

      it "downloads the public keys of that realm" do
        expect(resolver.find_public_keys("a-realm")).to_not be_nil
        expect(keycloak.realms).to eq ["a-realm"]
      end

      it "answers no public key for any other realm, and does not call Keycloak" do
        expect {
          resolver.find_public_keys("another-realm")
        }.to raise_error KeycloakApiRails::MissingPublicKeysError

        expect(keycloak.realms).to be_empty
      end
    end

    context "when several realms are configured" do
      let(:resolver) { resolver_for(["a-realm", "another-realm"]) }

      it "downloads the public keys of each of them, once each" do
        2.times { resolver.find_public_keys("a-realm") }
        2.times { resolver.find_public_keys("another-realm") }

        expect(keycloak.realms).to eq ["a-realm", "another-realm"]
      end

      it "answers no public key for a realm that is not one of them" do
        expect {
          resolver.find_public_keys("a-third-realm")
        }.to raise_error KeycloakApiRails::MissingPublicKeysError

        expect(keycloak.realms).to be_empty
      end

      # 'File.join' flattens an Array, so asking for no realm in particular used to download the
      # keys from '<server_url>/realms/a-realm/another-realm/protocol/openid-connect/certs'.
      it "answers no public key when no realm is named" do
        expect {
          resolver.find_public_keys
        }.to raise_error KeycloakApiRails::MissingPublicKeysError

        expect(keycloak.realms).to be_empty
      end
    end

    context "when the realms are decided by a Proc" do
      let(:resolver) { resolver_for(->(_realm_id) { true }) }
      let(:cap)      { KeycloakApiRails::PublicKeyCachedResolver::MAX_CACHED_REALMS }

      def resolve(realm_id)
        resolver.find_public_keys(realm_id)
      rescue KeycloakApiRails::MissingPublicKeysError
        nil
      end

      it "caches as many realms as the cap allows" do
        cap.times { |index| resolve("realm-#{index}") }

        expect(keycloak.realms.size).to eq cap
      end

      it "answers no public key beyond the cap, rather than caching one more realm" do
        cap.times { |index| resolve("realm-#{index}") }

        expect {
          resolver.find_public_keys("one-realm-too-many")
        }.to raise_error KeycloakApiRails::MissingPublicKeysError

        expect(keycloak.realms.size).to eq cap
      end

      it "keeps serving the realms it had already cached" do
        cap.times { |index| resolve("realm-#{index}") }
        resolve("one-realm-too-many")

        expect(resolver.find_public_keys("realm-0")).to_not be_nil
      end

      # Whoever names the realms must not get to choose how much the application writes to its logs.
      it "logs the first refusal only" do
        expect(logger).to receive(:warn).once

        10.times { |index| resolve(nil) }
      end
    end
  end
end
