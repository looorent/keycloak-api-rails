$:.push File.expand_path("../lib", __FILE__)

require "keycloak-api-rails/version"

Gem::Specification.new do |spec|
  spec.name        = "keycloak-api-rails"
  spec.version     = Keycloak::VERSION
  spec.authors     = ["Lorent Lempereur", "Matt Kimmel"]
  spec.email       = ["lorent.lempereur.dev@gmail.com", "matt.kimmel@prizepicks.com"]
  spec.homepage    = "https://github.com/myprizepicks/keycloak-api-rails"
  spec.summary     = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.description = "Rails middleware that validates Authorization token emitted by Keycloak"
  spec.license     = "MIT"

  spec.files = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.add_dependency "json-jwt",    ">= 1.11.0"

  spec.add_development_dependency "rspec",   "3.12.0"
  spec.add_development_dependency "timecop", "0.9.6"
  spec.add_development_dependency "byebug", "11.1.3"
end
