# frozen_string_literal: true

module KeycloakApiRails
  class PublicKeyCachedResolver
    FAILED_REFRESH_RETRY_DELAY_IN_SECONDS = 10
    MAX_CACHED_REALMS                     = 64

    class RealmCache
      attr_reader :cached_public_key_retrieved_at

      def initialize(http_client, realm_id)
        @resolver                       = PublicKeyResolver.new(http_client, realm_id)
        @cached_public_keys             = nil
        @cached_public_key_retrieved_at = nil
        @last_refresh_failure_at        = nil
        @last_refresh_error             = nil
        @mutex                          = Mutex.new
      end

      def find_public_keys(public_key_cache_ttl, logger)
        @mutex.synchronize do
          raise @last_refresh_error if refresh_recently_failed_without_any_cache?

          refresh_public_keys(logger) if public_keys_are_outdated?(public_key_cache_ttl)
          @cached_public_keys
        end
      end

      private

      def refresh_public_keys(logger)
        @cached_public_keys             = @resolver.find_public_keys
        @cached_public_key_retrieved_at = Time.now
        @last_refresh_failure_at        = nil
        @last_refresh_error             = nil
      rescue StandardError => e
        @last_refresh_failure_at = Time.now
        @last_refresh_error      = e
        raise if @cached_public_keys.nil?

        logger&.warn("KeycloakApiRails: could not refresh the public keys (#{e.class}: #{e.message}). Keeping the ones retrieved at #{@cached_public_key_retrieved_at}.")
      end

      def refresh_recently_failed_without_any_cache?
        @cached_public_keys.nil? &&
          !@last_refresh_failure_at.nil? &&
          Time.now <= @last_refresh_failure_at + FAILED_REFRESH_RETRY_DELAY_IN_SECONDS
      end

      def public_keys_are_outdated?(public_key_cache_ttl)
        @cached_public_keys.nil? ||
          @cached_public_key_retrieved_at.nil? ||
          (Time.now > @cached_public_key_retrieved_at + public_key_cache_ttl &&
            (@last_refresh_failure_at.nil? ||
              Time.now > @last_refresh_failure_at + FAILED_REFRESH_RETRY_DELAY_IN_SECONDS))
      end
    end

    def initialize(http_client, realm_id, public_key_cache_ttl, logger = nil)
      @http_client          = http_client
      @realm_id             = realm_id
      @configured_realms    = configured_realms(realm_id)
      @public_key_cache_ttl = public_key_cache_ttl
      @logger               = logger
      @caches               = {}
      @caches_mutex         = Mutex.new
      @refusal_logged       = false
    end

    def self.from_configuration(http_client, configuration)
      new(http_client, configuration.realm_id, configuration.public_key_cache_ttl, configuration.logger)
    end

    def find_public_keys(realm_id = nil)
      cache_for(realm_id || default_realm).find_public_keys(@public_key_cache_ttl, @logger)
    end

    # Keep this method backward-compatible for testing
    def cached_public_key_retrieved_at(realm_id = nil)
      cache_for(realm_id || default_realm).cached_public_key_retrieved_at
    end

    private

    def default_realm
      @realm_id if @realm_id.is_a?(String)
    end

    def configured_realms(realm_id)
      case realm_id
      when String then [realm_id].freeze
      when Array  then realm_id.dup.freeze
      end
    end

    def cache_for(realm_id)
      @caches[realm_id] || @caches_mutex.synchronize { @caches[realm_id] || create_cache(realm_id) }
    end

    def create_cache(realm_id)
      refuse(realm_id, "it is not one of the configured realms")         unless cacheable?(realm_id)
      refuse(realm_id, "#{MAX_CACHED_REALMS} realms are already cached") if     @caches.size >= MAX_CACHED_REALMS

      @caches[realm_id] = RealmCache.new(@http_client, realm_id)
    end

    def cacheable?(realm_id)
      !realm_id.nil? && (@configured_realms.nil? || @configured_realms.include?(realm_id))
    end

    def refuse(realm_id, reason)
      unless @refusal_logged
        @refusal_logged = true
        @logger&.warn("KeycloakApiRails: no public key is downloaded for the realm #{realm_id.inspect}, #{reason}. The requests naming it are answered a 503. Further refusals are not logged.")
      end

      raise MissingPublicKeysError, "No Keycloak public key can be downloaded for the realm #{realm_id.inspect}"
    end
  end
end
