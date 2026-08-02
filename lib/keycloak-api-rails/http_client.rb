# frozen_string_literal: true

module KeycloakApiRails
  class HTTPError < StandardError
    attr_reader :status

    def initialize(message, status = nil)
      super(message)
      @status = status
    end
  end

  class HTTPClient
    UNREACHABLE_ERRORS = [
      Timeout::Error,
      SocketError,
      SystemCallError,
      IOError,
      OpenSSL::SSL::SSLError,
      Net::ProtocolError
    ].freeze

    def initialize(configuration, logger)
      @configuration = configuration
      @logger        = logger
      @x509_store    = OpenSSL::X509::Store.new
      @x509_store.set_default_paths
      @x509_store.add_file(configuration.ca_certificate_file) if configuration.ca_certificate_file
    end

    def get(realm_id, path)
      @configuration.validate_server!

      uri      = build_uri(realm_id, path)
      response = request(uri)

      unless response.is_a?(Net::HTTPSuccess)
        @logger.error("KeycloakApiRails: Keycloak responded with an error when calling '#{path}'. Status #{response.code}. Payload: #{response.body}")
        raise HTTPError.new("Keycloak responded with a #{response.code} status when calling '#{path}'", response.code)
      end

      parse(response, path)
    end

    private

    def request(uri)
      Net::HTTP.start(uri.host,
                      uri.port,
                      use_ssl:      uri.scheme != "http",
                      cert_store:   @x509_store,
                      open_timeout: @configuration.http_open_timeout,
                      read_timeout: @configuration.http_read_timeout) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    rescue *UNREACHABLE_ERRORS => e
      @logger.error("KeycloakApiRails: could not reach Keycloak at '#{uri}'. #{e.class}: #{e.message}")
      raise HTTPError, "Could not reach Keycloak at '#{uri}': #{e.message}"
    end

    def parse(response, path)
      JSON.parse(response.body)
    rescue JSON::ParserError => e
      @logger.error("KeycloakApiRails: could not parse the response of '#{path}'. #{e.message}")
      raise HTTPError, "Keycloak returned a malformed JSON payload when calling '#{path}'"
    end

    def build_uri(realm_id, path)
      URI(File.join(@configuration.server_url, "realms", realm_id, path))
    end
  end
end
