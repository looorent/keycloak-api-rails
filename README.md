# Keycloak-Rails-Api

This gem validates Keycloak JWT token for Ruby On Rails APIs.

## Requirements

* Ruby `>= 2.7`
* Rails `>= 4.2`

Every push is tested against Ruby 2.7, 3.0, 3.1, 3.2, 3.3, 3.4 and 4.0. Each of them installs the
most recent dependencies it supports, so the test suite runs against Rails 7.1 (Ruby 2.7 and 3.0),
Rails 7.2 (Ruby 3.1) and Rails 8.1 (Ruby 3.2 and above).

Ruby 2.7 and 3.0 reached their end of life and no longer receive security fixes. They are supported
here so that applications running on Rails 7.0 and 7.1 can use this gem, but upgrading Ruby remains
the recommended path.

## Install

```ruby
gem "keycloak-api-rails", "1.1.1"
```

## Token validation

Tokens sent (through query strings or Authorization headers) are validated against a Keycloak public key. This public key is downloaded every day by default (this interval can be changed through `public_key_cache_ttl`).

## Pass token to the API

* Method 1: By adding an `Authorization` HTTP Header with its value set to `Bearer <your token>`.
  _e.g_ using curl: `curl -H "Authorization: Bearer <your-token>" https://api.pouet.io/api/more-pouets`
* Method 2: By providing the token via query string, especially via the parameter named `authorizationToken`. Keep in mind that this method is less secure (url are kept intact in your browser history, and so on...)
  _e.g._ using curl: `curl https://api.pouet.io/api/more-pouets?authorizationToken<your-token>`

_If both method are used at the same time, The query string as a higher priority when reading given tokens._

## Opt-in vs. Opt-out validation

By default, Keycloak-api-rails installs as a Rack Middleware. It processes all requests before any application logic. URIs/Paths can be excluded (opted-out) from this validation using the 'skip_paths' config option

Alternatively, it can be configured to `opt-in` to validation. In this case, no Rack middleware is used, and controllers can request (opt-in) by including the module `KeycloakApiRails::authentication` and calling `keycloak_authenticate`, for example in a `before_action`, like so: 

```ruby
class MyApiController < ActionController::Base
  include KeycloakApiRails::Authentication

  before_action :keycloak_authenticate
end
```

## When a token is validated

In Rails controller, the request `env` variables has two more properties:
* `keycloak:keycloak_id`
* `keycloak:roles`

They can be accessed using `KeycloakApiRails::Helper` methods.

## Overall configuration options

All options have a default value. However, all of them can be changed in your initializer file.

| Option | Default Value | Type | Required? | Description  | Example |
| ---- | ----- | ------ | ----- | ------ | ----- |
| `server_url` | `nil`| String | Required | The base url where your Keycloak server is located. This value can be retrieved in your Keycloak client configuration. | `auth:8080` |
| `realm_id` | `nil`| String | Required | Realm's name (not id, actually) | `master` |
| `logger` | `Logger.new(STDOUT)`| Logger | Optional | The logger used by `keycloak-api-rails` | `Rails.logger` | 
| `skip_paths` | `{}`| Hash of methods and paths regexp | Optional | Paths whose the token must not be validatefd | `{ get: [/^\/health\/.+/] }`| 
| `opt_in` | `false` | Boolean | Optional | When true, All requests will be validated (excluding requests matching `skip_paths`). When false, validation must be explicitly requested | `true`
| `token_expiration_tolerance_in_seconds` | `10`| Logger | Optional | Number of seconds a token can expire before being rejected by the API. | `15` | 
| `public_key_cache_ttl` | `86400`| Integer | Optional | Amount of time, in seconds, specifying maximum interval between two requests to {project_name} to retrieve new public keys. It is 86400 seconds (1 day) by default. At least once per this configured interval (1 day by default) will be new public key always downloaded. | `Rails.logger` | 
| `custom_attributes` | `[]`| Array Of String | Optional | List of token attributes to read from each token and to add to their http request env | `["originalFirstName", "originalLastName"]` | 
| `ca_certificate_file` | `nil`| String | Optional | Path to the certificate authority used to validate the Keycloak server certificate | `/credentials/production_root_ca_cert.pem` | 
## Configure it

Create a `keycloak.rb` file in your Rails `config/initializers` folder. For instance:

```
KeycloakApiRails.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ENV["KEYCLOAK_REALM_ID"]
  config.logger     = Rails.logger
  config.skip_paths = {
    post:   [/^\/message/],
    get:    [/^\/locales/, /^\/health\/.+/]
  }
end
```

Or using opt-in configuration:

```ruby
KeycloakApiRails.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ENV["KEYCLOAK_REALM_ID"]
  config.logger     = Rails.logger
  config.opt_in     = true
end
```

When using `opt-in` is true, `skip_paths` is not used. 

## Use cases

Once this gem is configured in your Rails project, you can read, validate and use tokens in your controllers.

### Keycloak Id

If you identify users using their Keycloak Id, this value can be read from your controllers using `KeycloakApiRails::Helper.current_user_id(request.env)`.

```ruby
class AuthenticatedController < ApplicationController

  def user
    keycloak_id = KeycloakApiRails::Helper.current_user_id(request.env)
    User.active.find_by(keycloak_id: keycloak_id)
  end
end
```

Or if using opt-in mode, the controller can request validation conditionally: 
```ruby
class MostlyAuthenticatedController < ApplicationController
  include KeycloakApiRails::Authentication

  before_action :keycloak_authenticate, only: show

  def show
    keycloak_id = KeycloakApiRails::Helper.current_user_id(request.env)
    User.active.find_by(keycloak_id: keycloak_id)
  end

  def index 
    # unauthenticated
  end
end
```

### Roles

`KeycloakApiRails::Helper.current_user_roles` can be use against a Rails request to read user's roles.

For example, a controller can require users to be administrator (considering you defined an `application-admin` role):

```ruby
class AdminController < ApplicationController

  before_action :require_to_be_admin!

  def require_to_be_admin!
    if !current_user_roles.include?("application-admin")
      render(json: { reason: "admin", message: "You have to be an administrator to access that endpoint." }, status: :forbidden)
    end
  end

  private

  def current_user_roles
    KeycloakApiRails::Helper.current_user_roles(request.env)
  end
end
```

### Create an URL where the token must be passed via query string

`KeycloakApiRails::Helper.create_url_with_token` method can be used to build an url from another, by adding a token as query string.

```ruby
def example
  KeycloakApiRails::Helper.create_url_with_token("https://api.pouet.io/api/more-pouets", "myToken")
end
```

This should output `https://api.pouet.io/api/more-pouets?authorizationToken=myToken`.


### Accessing Keycloak Service

A lazy-loaded service KeycloakApiRails::Service can be accessed using `KeycloakApiRails.service`.
For instance, to read a provided token:
```ruby
class RenderTokenController < ApplicationController
  def show
    uri     = request.env["REQUEST_URI"]
    headers = request.env
    token   = KeycloakApiRails.service.read_token(uri, headers)
    render json: { token: token }, status: :ok
  end
end
```

## Writing integration tests

If you want to write controller or request tests in your codebase and that Keycloak is configured for these controllers,
this gem provides the helpers that forge valid tokens, so that no Keycloak server is required.
These helpers are not loaded by `keycloak-api-rails`: they have to be required explicitly, so that nothing they define ends up in a production process.
These lines are based on tests written using `rspec`.

```ruby
# spec/rails_helper.rb
require "keycloak-api-rails/testing"

RSpec.configure do |config|
  config.include KeycloakApiRails::Testing::Helpers
  config.before(:suite) { KeycloakApiRails::Testing.stub_public_keys! }
end
```

`stub_public_keys!` makes the library validate the tokens forged by these helpers, instead of fetching public keys from a Keycloak server.
`server_url` and `realm_id` therefore do not have to be configured in the test environment. Requests can then be authenticated with:

```ruby
it "returns the current user" do
  get "/me", headers: keycloak_auth_headers(sub: user.keycloak_id)

  expect(response).to have_http_status(:ok)
end
```

`keycloak_auth_headers` returns an `Authorization` header, and `keycloak_token` returns the token alone.
Both accept the same optional parameters, one for each claim this library reads:

| Parameter | Claim | Default |
| --- | --- | --- |
| `sub` | `sub` | a random UUID |
| `email` | `email` | none |
| `locale` | `locale` | none |
| `authorized_party` | `azp` | none |
| `roles` | `realm_access.roles` | none |
| `resource_roles` | `resource_access` | none |
| `issued_at` | `iat` | now |
| `expires_at` | `exp` | one hour after `issued_at` |
| `claims` | any other claim | none |

For instance, to authenticate a request as a user having the realm role `admin`, the role `reader` on the client `a-client`,
and a `tenant_id` attribute declared in `config.custom_attributes`:

```ruby
headers = keycloak_auth_headers(sub:            user.keycloak_id,
                                roles:          ["admin"],
                                resource_roles: { "a-client" => ["reader"] },
                                claims:         { "tenant_id" => tenant.id })
```

An expired token is forged by passing an `expires_at` in the past, which is how a `401` can be tested.
Assigning `KeycloakApiRails.public_key_resolver = nil` restores the regular resolver.

## How to execute library tests

From the `keycloak-rails-api` directory:

```
  $ docker build . -t keycloak-rails-api:test
  $ docker run -v `pwd`:/usr/src/app/ keycloak-rails-api:test bundle exec rspec spec
```

## How to release a new version

Releases are published to [RubyGems](https://rubygems.org/gems/keycloak-api-rails) by GitHub Actions
(`.github/workflows/release.yml`), through [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/):
no API key is stored in this repository, the workflow exchanges a short-lived GitHub OIDC token for a
scoped RubyGems credential.

1. Update `KeycloakApiRails::VERSION` in `lib/keycloak-api-rails/version.rb` and the `CHANGELOG.md`
2. Commit and push these changes to `main`
3. Tag the commit and push the tag:

```
  $ git tag -a v1.2.0 -m "Version 1.2.0"
  $ git push origin v1.2.0
```

The workflow then checks that the tag matches `KeycloakApiRails::VERSION`, runs the tests, builds the gem
and pushes it. It only publishes tags starting with `v`.

## Next developments

* Manage multiple realms
* Avoid duplicate code in KeycloakApiRails::Middleware and `KeycloakApiRails::Authentication`