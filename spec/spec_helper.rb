require_relative "../lib/keycloak-api-rails"
require_relative "support/public_key_cached_resolver_stub"
require_relative "support/public_key_resolver_stub"
require "timecop"
require "byebug"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
end
