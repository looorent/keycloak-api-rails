module KeycloakApiRails
  class PublicKeyCachedResolver
    FAILED_REFRESH_RETRY_DELAY_IN_SECONDS = 10

    attr_reader :cached_public_key_retrieved_at

    def initialize(http_client, realm_id, public_key_cache_ttl, logger = nil)
      @resolver                       = PublicKeyResolver.new(http_client, realm_id)
      @public_key_cache_ttl           = public_key_cache_ttl
      @logger                         = logger
      @cached_public_keys             = nil
      @cached_public_key_retrieved_at = nil
      @last_refresh_failure_at        = nil
      @mutex                          = Mutex.new
    end

    def self.from_configuration(http_client, configuration)
      new(http_client, configuration.realm_id, configuration.public_key_cache_ttl, configuration.logger)
    end

    def find_public_keys
      @mutex.synchronize do
        raise @last_refresh_error if refresh_recently_failed_without_any_cache?

        refresh_public_keys if public_keys_are_outdated?
        @cached_public_keys
      end
    end

    private

    def refresh_public_keys
      @cached_public_keys             = @resolver.find_public_keys
      @cached_public_key_retrieved_at = Time.now
      @last_refresh_failure_at        = nil
      @last_refresh_error             = nil
    rescue StandardError => e
      @last_refresh_failure_at = Time.now
      @last_refresh_error      = e
      raise if @cached_public_keys.nil?

      @logger&.warn("KeycloakApiRails: could not refresh the public keys (#{e.class}: #{e.message}). Keeping the ones retrieved at #{@cached_public_key_retrieved_at}.")
    end

    def refresh_recently_failed_without_any_cache?
      @cached_public_keys.nil? &&
        !@last_refresh_failure_at.nil? &&
        Time.now <= @last_refresh_failure_at + FAILED_REFRESH_RETRY_DELAY_IN_SECONDS
    end

    def public_keys_are_outdated?
      @cached_public_keys.nil? ||
        @cached_public_key_retrieved_at.nil? ||
        (Time.now > @cached_public_key_retrieved_at + @public_key_cache_ttl &&
          (@last_refresh_failure_at.nil? ||
            Time.now > @last_refresh_failure_at + FAILED_REFRESH_RETRY_DELAY_IN_SECONDS))
    end
  end
end
