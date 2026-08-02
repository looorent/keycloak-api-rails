# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

* The realm named by the `iss` claim is read before the signature of the token is verified, and is interpolated in the URL its public keys are downloaded from. It is now refused unless it is a plain name: the unreserved characters of RFC 3986, at most 128 of them, and not a relative path segment. `https://keycloak/realms/master?` and `https://keycloak/realms/..` both are the last segment of a well-formed `iss`, and both used to build another URL than the one of the realm they name. Such a token is answered a `401`, reason `:invalid_realm`, and no request is sent to Keycloak.
* A token whose payload is not a JSON object, or whose `iss` claim is not a String, is answered a `401`. Reading such a payload used to raise a `NoMethodError` or a `TypeError` out of the middleware, and to be answered a `500`.
* The number of realms whose public keys are cached is now bounded. 
* A token was verified with whichever algorithm its `alg` header named. New `allowed_algorithms` option, defaulting to the asymmetric algorithms Keycloak signs with, and narrowable to the one of the realm. Symmetric algorithms are refused.

### Performance

* Added `# frozen_string_literal: true` to all ruby files and optimized Hot Path methods in `Service` and `Helper` (e.g., using `Regexp#match?`, avoiding redundant String-to-Symbol conversions) to significantly reduce CPU usage and memory allocations per request.

### Added

* Integration tests ensuring E2E compatibility with a real Keycloak server using Docker.
* Automated tests in CI against multiple Keycloak versions (19.0.3, 22.0.5, 25.0.0, 26.7.0).
* Enforced that the Rake `release` task cannot be executed locally without passing the test suite first.
* Multi-tenancy support: `realm_id` can now be a String, an Array of Strings, or a Proc (e.g., `->(env) { ... }`) that evaluates to a String or Array of Strings, allowing dynamic realm resolution per request.
* The middleware now validates the token against the allowed realms. A token carrying an `iss` claim that does not match one of the expected realms will be rejected. New `KeycloakApiRails::TokenError` reason: `:invalid_realm`.
* `PublicKeyCachedResolver` caches public keys per-realm, ensuring safe operation in a multi-tenant environment.

## [2.0.1] - 2026-08-02

### Security

* `skip_paths` declaring its paths as Strings, e.g. `{ get: ["/health/db"] }`, opened routes that had to be authenticated.
* A path that is not a `Regexp` is discarded by the middleware rather than matched, and a warning is logged naming it.
* With `verify_not_before` enabled, an `nbf` claim carried as null was read as an absent one, skipping the very check the option asks for. It is now rejected.
* A token whose `exp` or `nbf` claim is not a number of seconds is answered a `401`, where `Time.at` used to raise a `TypeError` and answer a `500`. The 2.0.0 guard only checked that `exp` was present, not that it held a NumericDate. New `KeycloakApiRails::TokenError` reason: `:invalid_claim`.

### Fixed

* `custom_attributes` declared as Symbols, e.g. `[:tenant_id]`, matched no claim at all: those of a decoded token are keyed by String. Both forms are honoured.
* `custom_attributes` holding something else than a claim name is reported by `Configuration#validate!`, instead of being silently read from no token.
* `KeycloakApiRails.configure` discards the service, the public key resolver and the HTTP client it had memoized

### Availability

* A request whose token cannot be verified at all, Keycloak being unreachable and no public key having ever been retrieved, is answered a `503` carrying a `Retry-After` header. `KeycloakApiRails::HTTPError` and `KeycloakApiRails::MissingPublicKeysError` used to escape the middleware, and `keycloak_authenticate`, as a `500`: an outage of Keycloak was reported as a bug of the application. A request carrying no token at all is still answered a `401`, and the paths of `skip_paths` are still served.
* With nothing cached, a Keycloak that is down was called again by every single request, one at a time behind the mutex of the resolver, each waiting for `http_open_timeout` and `http_read_timeout` to elapse: ten concurrent requests held ten threads for a hundred seconds. It is now called once per `FAILED_REFRESH_RETRY_DELAY_IN_SECONDS`, and the error of the last attempt is raised straight away in between.

## [2.0.0] - 2026-08-01

### Breaking changes

* `TokenError` is now namespaced: `KeycloakApiRails::TokenError`.
* The gem depends on `railties` rather than on the whole `rails` meta gem
* An invalid configuration raises `KeycloakApiRails::InvalidConfigurationError` when the application boots
* A token this library cannot read at all is answered a `401`, where an unexpected error used to escape the middleware as a `500`
* A token carried by the `authorizationToken` query string parameter is ignored unless the new `allow_token_in_query_string` option is enabled
* `KeycloakApiRails::HTTPClient` raises `KeycloakApiRails::HTTPError` when Keycloak answers an error, a malformed payload, or cannot be reached.

### Security

* New `expected_audience` option: when set, a token whose `aud` claim does not carry one of the expected audiences is rejected. Without it, every token signed by the realm is accepted (including its ID tokens) which Keycloak signs with the very same key, and the access tokens issued for its other clients
* New `expected_token_type` option: when set, a token whose `typ` claim does not match is rejected. Keycloak types its access tokens `Bearer`
* New `verify_not_before` option: when enabled, a token whose `nbf` claim is in the future is rejected. Disabled by default, since a clock skew between Keycloak and the API would reject valid tokens
* A token carrying no `exp` claim is rejected, where `Time.at(nil)` used to raise a `TypeError` and answer a `500`
* The resolver never answers without a public key: decoding a token without one would skip the signature verification altogether

### Fixed

* The `401` answered by the middleware carries a lowercase `content-type` header, as the Rack 3 SPEC requires.
* The `Authorization` header is read again when the Rack environment carries no `REQUEST_URI`. 
* A `TokenError` raised further down the stack is no longer swallowed by the middleware and turned into a `401`
* `skip_paths` declared with String or upcased HTTP methods, e.g. `{ "GET" => [...] }`, are honoured instead of silently never matching
* `TokenError.unknown` raised an `ArgumentError`, being called without any argument
* `TokenError.invalid_format` no longer reports a `nil` cause: the rescue clause read an `e` that was never bound
* `Helper.current_user_roles` was declared twice
* The `Authorization` scheme is read case-insensitively, as RFC 7235 requires, and any amount of whitespace may separate it from the token. `gsub(/^Bearer /, "")` also stripped the scheme from every line that followed the first one, `^` matching the beginning of any line in Ruby

### Thread safety

* The memoized service, public key resolver and HTTP client are built once per process, whichever thread reaches them first. Every thread of a threaded server used to build its own on the first request
* The public keys are downloaded once when several threads find the cache expired at the same time, rather than once per thread
* `KeycloakApiRails::Testing` generates a single key pair under a parallelized test suite. Two threads generating one each would leave the signing key and the published public key out of sync, failing the verification of every forged token

### Availability

* The requests downloading the public keys apply the new `http_open_timeout` and `http_read_timeout` options, 5 seconds each. Without them, `Net::HTTP` waits 60 seconds to open the connection and 60 more to read the answer: a Keycloak that hangs held every request thread of the API
* An unreachable Keycloak no longer takes the API down: the public keys retrieved last keep being used past their TTL, and a failed refresh is not attempted again for 10 seconds

### Added

* The configuration is validated at boot, and `Configuration#validate!` reports every problem at once
* A warning is logged at boot when `server_url` and `realm_id` are not both configured

### Upgrading from 1.x to 2.0

* `TokenError` has moved into the module of the library, and is now `KeycloakApiRails::TokenError`. An application rescuing it (typically around `keycloak_authenticate`) has to be updated. Its `reason` can now also be `:not_yet_valid`, `:invalid_audience`, `:invalid_token_type`, `:missing_claim` and `:unknown`
* A token carried by the `authorizationToken` query string parameter is ignored unless `config.allow_token_in_query_string = true` is set, and the `Authorization` header now takes precedence over it. An API whose clients pass their token through the URL (a browser following a link, a `<video>` tag) has to enable the option explicitly.
* The gem depends on `railties` instead of `rails`. An application that relied on this gem to pull Rails in has to declare `rails` itself
* A configuration mistake now raises a `KeycloakApiRails::InvalidConfigurationError` when the application boots, instead of failing on the first request
* A request carrying a token that this library cannot read at all is answered a `401` instead of raising, which used to result in a `500`
* Failing to download the public keys raises a `KeycloakApiRails::HTTPError`. It used to log the error and let the resolver fail later, with an unrelated `NoMethodError`

## [1.1.2] - 2026-08-01

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