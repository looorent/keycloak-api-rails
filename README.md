# Introduction

This gem aims at validates Keycloak JWT token in Ruby On Rails APIs.

## Blablabla

Tokens send (through query strings or Authorization headers) to this Railtie Middleware are validated against a Keycloak public key. This public key is downloaded every day by default (this interval can be changed through `public_key_cache_ttl`).

TODO

## Pass token to the API

* Method 1: In the `Authorization` HTTP Header like `Bearer <your token>`
* Method 2: As a query parameter named `authorization_token`

The query string as a higher priority when reading given tokens.

## When authenticated

The request `env` variables has two more properties:
* `keycloak:keycloak_id`
* `keycloak:roles`

They can be accessed using `Keycloak::Helper` methods.

## Overall configuration options

All options have a default value. However, all of them can be changed in your initializer file.

| Option | Default Value | Type | Required? | Description  | Example |
| ---- | ----- | ------ | ----- | ------ | ----- |
| `server_url` | `nil`| String | Required | The base url where your Keycloak server is located. This value can be retrieved in your Keycloak client configuration. | `auth:8080` |
| `realm_id` | `nil`| String | Required | TODO | `fdqgqdsg` |
| `logger` | `Logger.new(STDOUT)`| Logger | Optional | The logger used by `keycloak-api-rails` | `Rails.logger` | 
| `skip_paths` | `{}`| Hash of methods and paths regexp | Optional | TODO | TODO | 
| `token_expiration_tolerance_in_seconds` | `10`| Logger | Optional | TODO | `15` | 
| `public_key_cache_ttl` | `86400`| Integer | Optional | Amount of time, in seconds, specifying maximum interval between two requests to {project_name} to retrieve new public keys. It is 86400 seconds (1 day) by default. At least once per this configured interval (1 day by default) will be new public key always downloaded. | `Rails.logger` | 


## Configure it

Create a `keycloak.rb` file in your Rails `config/initializers` folder. For instance:

```
Keycloak.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ENV["KEYCLOAK_REALM_ID"]
  config.logger     = Rails.logger
  config.skip_paths = {
    post:   [/^\/message/],
    get:    [/^\/locales/, /^\/health\/.+/]
  }
end
```

## How to execute tests

From the `keycloak-rails-api` directory:

```
  $ docker build . -t keycloak-rails-api:test
  $ docker run -v `pwd`:/usr/src/app/ keycloak-rails-api:test bundle exec rspec spec
```
