require "net/http"
require "json"
require "uri"

module KeycloakHelper
  CONTAINER_NAME = "keycloak-api-rails-test-#{Time.now.to_i}"
  KEYCLOAK_URL = "http://127.0.0.1:8081"
  REALM_NAME = "test-realm"

  def self.start_keycloak
    puts "Starting Keycloak container..."
    keycloak_version = ENV.fetch("KEYCLOAK_VERSION", "19.0.3")
    # Starting Keycloak 19+ in dev mode
    # For testing, we just use start-dev which comes with an in-memory database and HTTP (no HTTPS required).
    system("docker run -d --name #{CONTAINER_NAME} -p 8081:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin -e KC_BOOTSTRAP_ADMIN_USERNAME=admin -e KC_BOOTSTRAP_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak:#{keycloak_version} start-dev")

    wait_for_keycloak
    configure_keycloak
  end

  def self.stop_keycloak
    puts "Stopping Keycloak container..."
    system("docker rm -f #{CONTAINER_NAME} > /dev/null 2>&1")
  end

  def self.wait_for_keycloak
    puts "Waiting for Keycloak to be ready..."
    90.times do
      begin
        response = Net::HTTP.get_response(URI("#{KEYCLOAK_URL}/"))
        if ["200", "302"].include?(response.code)
          puts "Keycloak is ready!"
          return
        end
      rescue StandardError
        # Ignored, wait and retry
      end
      sleep 1
    end
    system("docker logs #{CONTAINER_NAME}")
    raise "Keycloak did not start in time."
  end

  def self.configure_keycloak
    puts "Configuring Keycloak realm..."
    token = get_admin_token

    # Create Realm
    realm_payload = {
      id: REALM_NAME,
      realm: REALM_NAME,
      enabled: true,
      registrationAllowed: true,
      directGrantFlow: "direct grant"
    }
    post_request("#{KEYCLOAK_URL}/admin/realms", token, realm_payload)

    # Create Client
    client_payload = {
      clientId: "test-client",
      enabled: true,
      publicClient: true,
      directAccessGrantsEnabled: true
    }
    post_request("#{KEYCLOAK_URL}/admin/realms/#{REALM_NAME}/clients", token, client_payload)

    # Create User
    user_payload = {
      username: "testuser",
      enabled: true,
      email: "testuser@example.com",
      firstName: "Test",
      lastName: "User",
      emailVerified: true,
      credentials: [{ type: "password", value: "testpassword", temporary: false }]
    }
    post_request("#{KEYCLOAK_URL}/admin/realms/#{REALM_NAME}/users", token, user_payload)
  end

  def self.get_admin_token
    uri = URI("#{KEYCLOAK_URL}/realms/master/protocol/openid-connect/token")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      "client_id" => "admin-cli",
      "username" => "admin",
      "password" => "admin",
      "grant_type" => "password"
    )
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["access_token"]
  end

  def self.get_user_token
    uri = URI("#{KEYCLOAK_URL}/realms/#{REALM_NAME}/protocol/openid-connect/token")
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(
      "client_id" => "test-client",
      "username" => "testuser",
      "password" => "testpassword",
      "grant_type" => "password"
    )
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    raise "Failed to get user token: #{res.code} #{res.body}" unless res.code == "200"
    JSON.parse(res.body)["access_token"]
  end

  def self.post_request(url, token, payload)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"] = "application/json"
    req.body = payload.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    
    unless ["201", "200", "409"].include?(res.code) # 409 means already exists
      raise "Request to #{url} failed: #{res.code} #{res.body}"
    end
  end
end
