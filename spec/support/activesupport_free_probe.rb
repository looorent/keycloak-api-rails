# Loads the library and exercises every code path that used to rely on ActiveSupport,
# in a process where ActiveSupport is *not* loaded.
#
# The regular test suite loads `rails/all`, which makes ActiveSupport available everywhere and
# therefore cannot detect that the library depends on it again. This probe is executed in a
# separate process by spec/keycloak-api-rails/activesupport_free_spec.rb.
#
# The library files are required one by one on purpose: `lib/keycloak-api-rails.rb` pulls in
# `json/jwt`, which depends on ActiveSupport. The point of this probe is that *our* code does not
# use ActiveSupport, not that it never gets loaded by a third party.

require "uri"
require "date"
require "logger"

LIB = File.expand_path("../../../lib/keycloak-api-rails", __FILE__)

# Minimal stand-in for the parts of lib/keycloak-api-rails.rb the required files call at runtime.
module KeycloakApiRails
  class << self
    attr_accessor :config
  end
end

require "#{LIB}/configuration"
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
    %i[authentication_failed authentication_succeeded keycloak_authenticate]
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

### Service#expired? -- used to be `to_datetime` and `seconds`
configuration.token_expiration_tolerance_in_seconds = 10
configuration.skip_paths = {}
configuration.opt_in     = false
configuration.logger     = ::Logger.new(File::NULL)
service = KeycloakApiRails::Service.new(nil)
now = Time.now

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
