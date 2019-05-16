$:.push File.expand_path("../lib", __FILE__)

require "keycloak-api-rails/version"

Gem::Specification.new do |spec|
  spec.name        = "keycloak-api-rails"
  spec.version     = Keycloak::VERSION
  spec.authors     = ["Lorent Lempereur"]
  spec.email       = ["lorent.lempereur.dev@gmail.com"]
  spec.homepage    = "https://github.com/looorent/keycloak-api-rails"
  spec.summary     = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.description = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.license     = "MIT"

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.add_dependency "rails",       ">= 4.2"
  spec.add_dependency "json-jwt",    ">= 1.9.4"
  spec.add_dependency "rest-client", ">= 2.0.2"

  spec.add_development_dependency "rspec",   "3.7.0"
  spec.add_development_dependency "timecop", "0.9.1"
  spec.add_development_dependency "byebug", "9.1.0"
end