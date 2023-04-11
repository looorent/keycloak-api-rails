# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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