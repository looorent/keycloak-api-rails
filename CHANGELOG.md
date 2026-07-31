# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

* Gem metadata
* The published gem no longer ships non-production code


## [1.1.1] - 2026-07-31

* New test helpers, in `keycloak-api-rails/testing`: `KeycloakApiRails::Testing.stub_public_keys!` validates the tokens forged by `keycloak_token` and `keycloak_auth_headers`, so that controller and request tests can be authenticated without a Keycloak server, and without the boilerplate the README used to describe. This file is not loaded by `keycloak-api-rails` and has to be required explicitly
* Publish the gem to RubyGems from Github Actions when a `v*` tag is pushed, using RubyGems' Trusted Publishing

## [1.1.0] - 2026-07-31

* Dependencies: Upgrade test dependency `timecop` to `0.9.11`
* Upgrade Docker image to Ruby 3.4
* Remove all usages of `ActiveSupport` from the library, replaced by plain Ruby
* Support Ruby 2.7 up to 4.0: declare `required_ruby_version >= 2.7` and stop committing `Gemfile.lock`, so that each Ruby version resolves the dependencies it supports (Rails 7.1 on Ruby 2.7 and 3.0, Rails 7.2 on Ruby 3.1, Rails 8.1 on Ruby 3.2 and above)
* Test dependency `byebug` is no longer pinned to an exact version, since byebug 12 requires Ruby 3.1

## [1.0.0] - 2025-12-10

* *[BREAKING CHANGE!]* Rename top-level module from `Keycloak` to `KeycloakApiRails` to avoid conflicts with other gems. (thanks to @eilers)
  * *Migration: Please do a global find and replace of `Keycloak.` to `KeycloakApiRails.` in your application.*
* Automate tests on Github Actions
* Dependencies: Upgrade test dependencies: timecop, rspec and byebug.

## [0.12.4] - 2024-06-20

* Log error when fetching the public keys from Keycloak

## [0.12.3] - 2024-06-20

* Add a debug log when not being able to validate a JWT

## [0.12.2] - 2023-06-03

* Avoid methods `logger`, `service` an `config` of `Keycloak::Authentication` to conflict with other concerns, such as rails. (thanks to @mkrawc)

## [0.12.1] - 2023-04-15

* Fixes for opt-in mode (#48) (thanks to @theSteveMitchell)

## [0.12.0] - 2023-04-11

* Introduce Opt-in mode as an alternative configuration (thanks to @theSteveMitchell)

## [0.11.2] - 2022-03-30

* Update `Gemfile.lock` to avoid wrong CVE detections. The version of Rails should always be specified by the parent project. This change has no functional impact.
* Update `json-jwt` to `>=1.13.0`

## [0.11.1] - 2019-11-27

* When a token validation error occurs, do not log it as a `warn` (but as an `info` instead)

## [0.11.0] - 2019-11-21

* Remove dependency to `rest-client` (thanks to @loicvigneron)
* Access Authorization Party from ENV (thanks to @loicvigneron)
* New configuration option: `ca_certificate_file` (thanks to @loicvigneron)
* Access the token from ENV
* Upgrade `json-jwt` to `1.11.0`