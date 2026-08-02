$:.push File.expand_path("../lib", __FILE__)

require "keycloak-api-rails/version"

Gem::Specification.new do |spec|
  spec.name        = "keycloak-api-rails"
  spec.version     = KeycloakApiRails::VERSION
  spec.authors     = ["Lorent Lempereur"]
  spec.email       = ["lorent.lempereur.dev@gmail.com"]
  spec.homepage    = "https://github.com/looorent/keycloak-api-rails"
  spec.summary     = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.description = "Rack middleware that validates the Keycloak JWT access token carried by every " \
                     "request of a Ruby on Rails API. It verifies the token signature against the " \
                     "realm public keys, exposes the authenticated user, its roles and the custom " \
                     "attributes of the token to the controllers, and lets some routes opt out of " \
                     "authentication."
  spec.license     = "MIT"

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.glob(["lib/**/*.rb", "CHANGELOG.md", "MIT-LICENSE", "README.md", "keycloak-api-rails.gemspec"])
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "railties",    ">= 4.2"
  spec.add_dependency "json-jwt",    ">= 1.11.0"

  spec.add_dependency "base64"
  spec.add_dependency "logger"

  spec.add_development_dependency "rspec",   "3.13.2"
  spec.add_development_dependency "timecop", "0.9.11"
  spec.add_development_dependency "rails",   ">= 4.2"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "rake",    ">= 13.0"
  spec.add_development_dependency "byebug", ">= 11.1.3"
  spec.add_development_dependency "bundler-audit", ">= 0.9"
end
