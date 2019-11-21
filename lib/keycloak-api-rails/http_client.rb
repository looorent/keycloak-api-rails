module Keycloak
  class HTTPClient
    def initialize(configuration)
      @server_url          = configuration.server_url
      @ca_certificate_file = configuration.ca_certificate_file
      @x509_store          = OpenSSL::X509::Store.new
      @x509_store.set_default_paths
      @x509_store.add_file(@ca_certificate_file) if @ca_certificate_file
    end

    def get(realm_id, path)
      uri          = build_uri(realm_id, path)
      use_ssl      = uri.scheme == "http" ? false : true
      Net::HTTP.start(uri.host, uri.port, :use_ssl => use_ssl, :cert_store => @x509_store) do |http|
        request  = Net::HTTP::Get.new(uri)
        response = http.request(request)
        JSON.parse(response.body)
      end
    end

    private

    def build_uri(realm_id, path)
      string_uri = File.join(@server_url, "realms", realm_id, path)
      URI(string_uri)
    end
  end
end
