$:.push File.expand_path("../lib", __FILE__)

require "keycloak-api-rails/version"

Gem::Specification.new do |spec|
  spec.name        = "keycloak-api-rails"
  spec.version     = KeycloakApiRails::VERSION
  spec.authors     = ["Lorent Lempereur"]
  spec.email       = ["lorent.lempereur.dev@gmail.com"]
  spec.homepage    = "https://github.com/looorent/keycloak-api-rails"
  spec.summary     = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.description = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.license     = "MIT"

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency "rails",       ">= 4.2"
  spec.add_dependency "json-jwt",    ">= 1.11.0"

  spec.add_development_dependency "rspec",   "3.13.2"
  spec.add_development_dependency "timecop", "0.9.11"
  # Required by 'rake release', which builds and publishes the gem from the CI.
  spec.add_development_dependency "rake",    ">= 13.0"
  # Not pinned to an exact version: byebug 12 requires Ruby >= 3.1, byebug 13 requires Ruby >= 3.2.
  # Older Rubies resolve to byebug 11.
  spec.add_development_dependency "byebug", ">= 11.1.3"
end
