module KeycloakApiRails
  class InvalidConfigurationError < StandardError; end

  class Configuration
    LOGGER_METHODS = [:debug, :info, :warn, :error].freeze

    attr_accessor :server_url
    attr_accessor :realm_id
    attr_accessor :skip_paths
    attr_accessor :opt_in
    attr_accessor :token_expiration_tolerance_in_seconds
    attr_accessor :public_key_cache_ttl
    attr_accessor :custom_attributes
    attr_accessor :logger
    attr_accessor :ca_certificate_file
    attr_accessor :expected_audience
    attr_accessor :expected_token_type
    attr_accessor :verify_not_before
    attr_accessor :allow_token_in_query_string
    attr_accessor :http_open_timeout
    attr_accessor :http_read_timeout

    def validate!
      errors = []

      errors.push("'server_url' must be a String or nil, got #{server_url.inspect}") unless server_url.nil? || server_url.is_a?(String)
      errors.push("'realm_id' must be a String or nil, got #{realm_id.inspect}") unless realm_id.nil? || realm_id.is_a?(String)
      errors.push("'logger' must respond to #{LOGGER_METHODS.join(', ')}") unless LOGGER_METHODS.all? { |method| logger.respond_to?(method) }
      errors.push("'opt_in' must be true or false, got #{opt_in.inspect}") unless boolean?(opt_in)
      errors.push("'verify_not_before' must be true or false, got #{verify_not_before.inspect}") unless boolean?(verify_not_before)
      errors.push("'allow_token_in_query_string' must be true or false, got #{allow_token_in_query_string.inspect}") unless boolean?(allow_token_in_query_string)
      errors.push("'token_expiration_tolerance_in_seconds' must be a number of seconds, got #{token_expiration_tolerance_in_seconds.inspect}") unless number?(token_expiration_tolerance_in_seconds, allow_zero: true)
      errors.push("'public_key_cache_ttl' must be a positive number of seconds, got #{public_key_cache_ttl.inspect}") unless number?(public_key_cache_ttl)
      errors.push("'http_open_timeout' must be a positive number of seconds, got #{http_open_timeout.inspect}") unless number?(http_open_timeout)
      errors.push("'http_read_timeout' must be a positive number of seconds, got #{http_read_timeout.inspect}") unless number?(http_read_timeout)
      errors.push("'expected_token_type' must be a String or nil, got #{expected_token_type.inspect}") unless expected_token_type.nil? || expected_token_type.is_a?(String)
      errors.push("'ca_certificate_file' must be the path of a readable file, got #{ca_certificate_file.inspect}") unless ca_certificate_file.nil? || File.readable?(ca_certificate_file.to_s)

      errors.concat(custom_attributes_errors)
      errors.concat(skip_paths_errors)
      errors.concat(expected_audience_errors)

      raise InvalidConfigurationError, "Invalid Keycloak configuration: #{errors.join('; ')}" unless errors.empty?

      true
    end

    def validate_server!
      errors = []
      errors.push("'server_url' must be configured, e.g. 'https://keycloak.example.org'") if missing?(server_url)
      errors.push("'realm_id' must be configured, e.g. 'master'") if missing?(realm_id)

      raise InvalidConfigurationError, "Invalid Keycloak configuration: #{errors.join('; ')}" unless errors.empty?

      true
    end

    def server_configured?
      !missing?(server_url) && !missing?(realm_id)
    end

    private

    def custom_attributes_errors
      if custom_attributes.is_a?(Array)
        invalid_names = custom_attributes.reject { |name| name.is_a?(String) || name.is_a?(Symbol) }
        if invalid_names.empty?
          []
        else
          ["'custom_attributes' must only contain claim names, as Strings or Symbols, got #{invalid_names.inspect}"]
        end
      else
        ["'custom_attributes' must be an Array of claim names, got #{custom_attributes.inspect}"] 
      end
    end

    def skip_paths_errors
      return ["'skip_paths' must be a Hash of HTTP methods and path regexps, got #{skip_paths.inspect}"] unless skip_paths.is_a?(Hash)

      skip_paths.filter_map do |method, paths|
        next if paths.is_a?(Array) && paths.all? { |path| path.is_a?(Regexp) }

        "'skip_paths[#{method.inspect}]' must be an Array of regexps, got #{paths.inspect}. A String is refused because 'String#match' compiles its argument into a regexp: the path of the request would become the pattern, and routes that must be authenticated would be skipped"
      end
    end

    def expected_audience_errors
      case expected_audience
      when nil, String
        []
      when Array
        expected_audience.all? { |audience| audience.is_a?(String) } ? [] : ["'expected_audience' must only contain Strings, got #{expected_audience.inspect}"]
      else
        ["'expected_audience' must be a String, an Array of Strings, or nil, got #{expected_audience.inspect}"]
      end
    end

    def boolean?(value)
      value == true || value == false
    end

    def number?(value, allow_zero: false)
      value.is_a?(Numeric) && (allow_zero ? value >= 0 : value > 0)
    end

    def missing?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
