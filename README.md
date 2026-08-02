# Keycloak-Rails-Api

This gem validates Keycloak JWT token for Ruby On Rails APIs.

## Requirements

* Ruby `>= 2.7`
* Railties `>= 4.2` — only `Rails::Railtie` is used

Every push is tested against Ruby 2.7, 3.0, 3.1, 3.2, 3.3, 3.4 and 4.0. Each of them installs the
most recent dependencies it supports, so the test suite runs against Rails 7.1 (Ruby 2.7 and 3.0),
Rails 7.2 (Ruby 3.1) and Rails 8.1 (Ruby 3.2 and above).

Ruby 2.7 and 3.0 reached their end of life and no longer receive security fixes. They are supported
here so that applications running on Rails 7.0 and 7.1 can use this gem, but upgrading Ruby remains
the recommended path.

## Install

```ruby
gem "keycloak-api-rails", "2.0.2"
```

## Token validation

Tokens are validated against a Keycloak public key. This public key is downloaded every day by default (this interval can be changed through `public_key_cache_ttl`).

## Pass token to the API

* Method 1: By adding an `Authorization` HTTP Header with its value set to `Bearer <your token>`. The scheme is case-insensitive.  _e.g_ using curl: `curl -H "Authorization: Bearer <your-token>" https://api.pouet.io/api/more-pouets`
* Method 2: By providing the token via query string, in the parameter named `authorizationToken`. This method has to be enabled explicitly, through `config.allow_token_in_query_string = true`: a token carried by a URL is kept in the browser history, sent along in the `Referer` header, and written to the access logs of every proxy on the way. _e.g._ using curl: `curl https://api.pouet.io/api/more-pouets?authorizationToken=<your-token>`

_If both methods are used at the same time, the `Authorization` header takes precedence: it is the one that does not leak._

## Opt-in vs. Opt-out validation

By default, Keycloak-api-rails installs as a Rack Middleware. It processes all requests before any application logic. URIs/Paths can be excluded (opted-out) from this validation using the 'skip_paths' config option

Alternatively, it can be configured to `opt-in` to validation. In this case, no Rack middleware is used, and controllers can request (opt-in) by including the module `KeycloakApiRails::Authentication` and calling `keycloak_authenticate`, for example in a `before_action`, like so: 

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
| `server_url` | `nil`| String | Required | The base url where your Keycloak server is located. This value can be retrieved in your Keycloak client configuration. | `auth:8080` |
| `realm_id` | `nil`| String, Array or Proc | Required | Realm's name(s) (not id, actually). Can be a single String, an Array of Strings for multiple tenants, or a Proc for dynamic validation. | `"master"` or `["tenant1", "tenant2"]` |
| `logger` | `Logger.new(STDOUT)`| Logger | Optional | The logger used by `keycloak-api-rails` | `Rails.logger` | 
| `skip_paths` | `{}`| Hash of methods and paths regexp | Optional | Paths whose token must not be validated, matched against the URL-decoded path of the request. Each path must be a `Regexp`, anchored with `\A` and `\z`: a String is refused when the application boots, and `^` and `$` are warned about, for the reasons given below | `{ get: [/\A\/health\/.+/] }`| 
| `opt_in` | `false` | Boolean | Optional | When false, every request is validated by the middleware, except the ones matching `skip_paths`. When true, no middleware validates anything and authentication must be requested explicitly, by calling `keycloak_authenticate` from a controller | `true`
| `token_expiration_tolerance_in_seconds` | `10`| Integer | Optional | Safety margin: a token is rejected this number of seconds *before* the date of its `exp` claim, so that it cannot expire in the middle of a request | `15` |
| `public_key_cache_ttl` | `86400`| Integer | Optional | Amount of time, in seconds, specifying maximum interval between two requests to Keycloak to retrieve new public keys. It is 86400 seconds (1 day) by default. At least once per this configured interval (1 day by default) will be new public key always downloaded. The refresh happens under a lock and blocks request threads if Keycloak hangs; reducing this TTL increases the frequency of this risk. | `3600` |
| `custom_attributes` | `[]`| Array of String or Symbol | Optional | List of token attributes to read from each token and to add to their http request env | `["originalFirstName", "originalLastName"]` |
| `ca_certificate_file` | `nil`| String | Optional | Path to the certificate authority used to validate the Keycloak server certificate | `/credentials/production_root_ca_cert.pem` |
| `expected_audience` | `nil`| String or Array of String | Optional | When set, a token is rejected unless its `aud` claim carries one of these audiences. Left unset, every token signed by the realm is accepted, including its ID tokens and the tokens issued for its other clients | `"my-api"` |
| `expected_token_type` | `nil`| String | Optional | When set, a token is rejected unless its `typ` claim matches (case-insensitive). Keycloak types its access tokens `Bearer` | `"Bearer"` |
| `allowed_algorithms` | every asymmetric algorithm Keycloak signs with: `[:RS256, :RS384, :RS512, :PS256, :PS384, :PS512, :ES256, :ES384, :ES512]` | Array of String or Symbol | Optional | The algorithms a token may be signed with. Narrow it down to the one of the realm, so that the `alg` header of a token cannot pick how its own signature is verified. Symmetric algorithms are refused: a token checked against a JWKS is checked against a public key, and a key that verifies is a key that signs | `[:RS256]` |
| `verify_not_before` | `false`| Boolean | Optional | When true, a token whose `nbf` claim is in the future is rejected. Disabled by default: a clock skew between Keycloak and the API would reject valid tokens | `true` |
| `allow_token_in_query_string` | `false`| Boolean | Optional | When true, a request carrying no `Authorization` header may be authenticated by the `authorizationToken` parameter of its query string | `true` |
| `http_open_timeout` | `5`| Integer | Optional | Seconds to wait for the connection to Keycloak to open, when downloading the public keys | `2` |
| `http_read_timeout` | `5`| Integer | Optional | Seconds to wait for the answer of Keycloak, when downloading the public keys | `2` |

The configuration is validated when the application boots: a mistake in the initializer raises a
`KeycloakApiRails::InvalidConfigurationError` naming the offending option, rather than failing on
the first request that reaches the middleware.

## Configure it

Create a `keycloak.rb` file in your Rails `config/initializers` folder. For instance:

```
KeycloakApiRails.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ENV["KEYCLOAK_REALM_ID"]
  config.logger     = Rails.logger
  config.skip_paths = {
    post:   [/\A\/message/],
    get:    [/\A\/locales/, /\A\/health\/.+/]
  }
end
```

Anchor those regexps with `\A` and `\z`, never with `^` and `$`. In Ruby, `^` and `$` match the
beginning and the end of a *line*, not of the string. The path they are matched against is
`PATH_INFO`, which the server has already URL-decoded, so a `%0a` in the request reaches them as a
real newline: `"/private\n/health"` matches `/^\/health/` and skips authentication on a path that
was never meant to be open. A regexp anchored with `^` or `$` is warned about when the first request
is served.

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

## Restricting which tokens are accepted

A token is always checked against the public keys of the realm, and against its expiration date.
That alone accepts *every* token the realm signed: the ID token of the same user, and the access tokens issued for the other clients of that realm. Declaring the audience the API expects.
The `aud` claim, and the type of token it accepts, the `typ` claim, which Keycloak sets to `Bearer` on its access tokens, narrows that down:

```ruby
KeycloakApiRails.configure do |config|
  config.server_url          = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id            = ENV["KEYCLOAK_REALM_ID"]
  config.expected_audience   = "my-api"
  config.expected_token_type = "Bearer"
end
```

Keycloak only adds an API to the `aud` claim of a token once that API is declared as an audience of the client requesting it, through an *audience mapper* on the client scope. Check what your realm actually issues before enabling `expected_audience`, or every request will be answered a `401`.

`config.verify_not_before = true` additionally rejects a token whose `nbf` claim is in the future.
It is disabled by default because a clock skew between Keycloak and the API rejects valid tokens.

## Multi-tenancy (Multiple Realms)

The library natively supports multi-tenancy by validating tokens issued by multiple Keycloak realms. 
Instead of a static string, you can configure `realm_id` with an Array or a Proc. The library will dynamically extract the realm from the token's `iss` claim, check if it is permitted, and fetch the appropriate public keys for that specific realm.

Using an Array of allowed realms:
```ruby
KeycloakApiRails.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ["master", "tenant-1", "tenant-2"]
end
```

Using a Proc for dynamic validation (e.g., querying the database):
```ruby
KeycloakApiRails.configure do |config|
  config.server_url = ENV["KEYCLOAK_SERVER_URL"]
  config.realm_id   = ->(realm) { Tenant.exists?(name: realm) }
end
```

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

Such an URL is only accepted by an API that set `config.allow_token_in_query_string = true`.


### Accessing Keycloak Service

A lazy-loaded service KeycloakApiRails::Service can be accessed using `KeycloakApiRails.service`.
For instance, to read a provided token:
```ruby
class RenderTokenController < ApplicationController
  def show
    uri     = KeycloakApiRails::Helper.request_uri(request.env)
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
  $ git tag -a v2.0.2 -m "Version 2.0.2"
  $ git push origin v2.0.2
```

The workflow then checks that the tag matches `KeycloakApiRails::VERSION`, runs the tests, builds the gem
and pushes it. It only publishes tags starting with `v`.
