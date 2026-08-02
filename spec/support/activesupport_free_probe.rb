# Loads the library and exercises every code path that used to rely on ActiveSupport,
# in a process where ActiveSupport is *not* loaded.
#
# The regular test suite loads `rails/all`, which makes ActiveSupport available everywhere and
# therefore cannot detect that the library depends on it again. This probe is executed in a
# separate process by spec/keycloak-api-rails/activesupport_free_spec.rb.

require "uri"
require "date"
require "logger"

LIB = File.expand_path("../../../lib/keycloak-api-rails", __FILE__)

module KeycloakApiRails
  class << self
    attr_accessor :config
  end
end

require "#{LIB}/configuration"
require "#{LIB}/token_error"
require "#{LIB}/helper"
require "#{LIB}/authentication"
require "#{LIB}/public_key_resolver"
require "#{LIB}/public_key_cached_resolver"
require "#{LIB}/service"

$failures = []

def assert(description)
  $failures << description unless yield
rescue => e
  $failures << "#{description} (raised #{e.class}: #{e.message})"
end

assert("ActiveSupport is not loaded by the library") { !defined?(ActiveSupport) }

### Configuration -- used to be ActiveSupport::Configurable
configuration = KeycloakApiRails::Configuration.new
KeycloakApiRails.config = configuration

%i[
  server_url realm_id skip_paths opt_in token_expiration_tolerance_in_seconds
  public_key_cache_ttl custom_attributes logger ca_certificate_file
  expected_audience expected_token_type verify_not_before allow_token_in_query_string
  http_open_timeout http_read_timeout
].each do |name|
  assert("Configuration##{name} is nil until it is assigned") { configuration.public_send(name).nil? }
  configuration.public_send("#{name}=", "a value for #{name}")
  assert("Configuration##{name} returns what was assigned") { configuration.public_send(name) == "a value for #{name}" }
end

### Authentication -- used to be ActiveSupport::Concern
declared_helper_methods = []
controller_with_helpers = Class.new do
  define_singleton_method(:helper_method) { |*names| declared_helper_methods.concat(names) }
end
controller_with_helpers.include(KeycloakApiRails::Authentication)
assert("Authentication declares keycloak_authenticate as a helper method") do
  declared_helper_methods == [:keycloak_authenticate]
end
assert("Authentication can be included in a class without helper_method") do
  Class.new.include(KeycloakApiRails::Authentication)
  true
end
assert("Authentication keeps its methods protected") do
  KeycloakApiRails::Authentication.protected_instance_methods.sort ==
    %i[authentication_failed authentication_succeeded authentication_unavailable keycloak_authenticate]
end

### Helper#read_token_from_query_string -- used to be `present?` and `second`
{
  nil                                                             => "",
  ""                                                              => "",
  "   "                                                           => "",
  "http://www.an-url.io/health"                                   => nil,
  "http://www.an-url.io/health?firstName=ouioui"                  => nil,
  "http://www.an-url.io/health?authorizationToken=aToken"         => "aToken",
  "http://www.an-url.io/health?a=1&authorizationToken=aToken&b=2" => "aToken",
}.each do |uri, expected|
  assert("Helper.read_token_from_query_string(#{uri.inspect}) returns #{expected.inspect}") do
    KeycloakApiRails::Helper.read_token_from_query_string(uri) == expected
  end
end

### Helper.request_uri -- rebuilds the URI from the keys the Rack SPEC mandates
{
  { "REQUEST_URI" => "/health?a=1" }                 => "/health?a=1",
  { "PATH_INFO" => "/health", "QUERY_STRING" => "" } => "/health",
  { "PATH_INFO" => "/health", "QUERY_STRING" => nil } => "/health",
  { "PATH_INFO" => "/health", "QUERY_STRING" => "a=1" } => "/health?a=1",
}.each do |env, expected|
  assert("Helper.request_uri(#{env.inspect}) returns #{expected.inspect}") do
    KeycloakApiRails::Helper.request_uri(env) == expected
  end
end

### Service#expired? -- used to be `to_datetime` and `seconds`
configuration.token_expiration_tolerance_in_seconds = 10
configuration.skip_paths           = {}
configuration.opt_in               = false
configuration.logger               = ::Logger.new(File::NULL)
configuration.expected_audience           = nil
configuration.expected_token_type         = nil
configuration.verify_not_before           = false
configuration.allow_token_in_query_string = false
service = KeycloakApiRails::Service.new(nil)
now = Time.now

### Service#read_token -- the 'Authorization' header comes first, and the query string is opt-in
{
  ["/health", { "HTTP_AUTHORIZATION" => "Bearer a-token" }]                             => "a-token",
  [nil, { "HTTP_AUTHORIZATION" => "Bearer a-token" }]                                   => "a-token",
  ["/health", { "HTTP_AUTHORIZATION" => "bearer a-token" }]                             => "a-token",
  ["/health", { "HTTP_AUTHORIZATION" => "Bearer a-token\nBearer another" }]             => "a-token\nBearer another",
  ["/health?authorizationToken=another", { "HTTP_AUTHORIZATION" => "Bearer a-token" }]  => "a-token",
  ["/health?authorizationToken=another", {}]                                            => "",
  ["/health", {}]                                                                       => "",
}.each do |(uri, headers), expected|
  assert("Service#read_token(#{uri.inspect}, #{headers.inspect}) returns #{expected.inspect}") do
    service.read_token(uri, headers) == expected
  end
end

configuration.allow_token_in_query_string = true
query_string_service = KeycloakApiRails::Service.new(nil)
{
  ["/health?authorizationToken=another", { "HTTP_AUTHORIZATION" => "Bearer a-token" }] => "a-token",
  ["/health?authorizationToken=another", {}]                                           => "another",
}.each do |(uri, headers), expected|
  assert("Service#read_token(#{uri.inspect}, #{headers.inspect}) returns #{expected.inspect} when the query string is allowed") do
    query_string_service.read_token(uri, headers) == expected
  end
end
configuration.allow_token_in_query_string = false

### Service#should_skip? -- HTTP methods are normalized
configuration.skip_paths = { "GET" => [%r{^/health}] }
skipping_service = KeycloakApiRails::Service.new(nil)
{
  ["GET", "/health/ready"] => true,
  [:get, "/health/ready"]  => true,
  ["GET", "/things"]       => false,
  ["POST", "/health"]      => false,
}.each do |(method, path), expected|
  assert("Service#should_skip?(#{method.inspect}, #{path.inspect}) returns #{expected}") do
    skipping_service.send(:should_skip?, method, path) == expected
  end
end
configuration.skip_paths = {}

{
  "expiring in one hour"                         => [(now + 3600).to_i, false],
  "expired two days ago"                         => [(now - 172800).to_i, true],
  "expiring within the tolerance (5s < 10s)"     => [(now + 5).to_i, true],
  "expiring after the tolerance (30s > 10s)"     => [(now + 30).to_i, false],
}.each do |description, (exp, expected)|
  assert("Service#expired? returns #{expected} for a token #{description}") do
    service.send(:expired?, { "exp" => exp }) == expected
  end
end

### PublicKeyCachedResolver -- used to be `seconds`
ttl = 86400
resolver = KeycloakApiRails::PublicKeyCachedResolver.new(nil, "a-realm", ttl)
assert("PublicKeyCachedResolver considers an empty cache as outdated") do
  resolver.send(:public_keys_are_outdated?) == true
end
resolver.instance_variable_set(:@cached_public_keys, "a-public-key")
resolver.instance_variable_set(:@cached_public_key_retrieved_at, Time.now - (ttl - 10))
assert("PublicKeyCachedResolver keeps a cache that is within its TTL") do
  resolver.send(:public_keys_are_outdated?) == false
end
resolver.instance_variable_set(:@cached_public_key_retrieved_at, Time.now - (ttl + 10))
assert("PublicKeyCachedResolver invalidates a cache that outlived its TTL") do
  resolver.send(:public_keys_are_outdated?) == true
end

assert("ActiveSupport has not been loaded while exercising the library") { !defined?(ActiveSupport) }

if $failures.empty?
  puts "The library behaves correctly without ActiveSupport"
  exit 0
else
  $failures.each { |failure| puts "FAILED: #{failure}" }
  exit 1
end
