# Keycloak-Rails-Api

This gem aims at validates Keycloak JWT token in Ruby On Rails APIs.

## Token validation

Tokens send (through query strings or Authorization headers) to this Railtie Middleware are validated against a Keycloak public key. This public key is downloaded every day by default (this interval can be changed through `public_key_cache_ttl`).

## Pass token to the API

* Method 1: By adding an `Authorization` HTTP Header with its value set to `Bearer <your token>`. 
  _e.g_ using curl: `curl -H "Authorization: Bearer <your-token>" https://api.pouet.io/api/more-pouets`
* Method 2: By providing the token via query string, especially via the parameter named `authorizationToken`. Keep in mind that this method is less secure (url are kept intact in your browser history, and so on...)
  _e.g._ using curl: `curl https://api.pouet.io/api/more-pouets?authorizationToken<your-token>`

_If both method are used at the same time, The query string as a higher priority when reading given tokens._

## When a token is validated

In Rails controller, the request `env` variables has two more properties:
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
| `skip_paths` | `{}`| Hash of methods and paths regexp | Optional | Paths whose the token must not be validatefd | `{ get: [/^\/health\/.+/] }`| 
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

## Use cases

Once this gem is configured in your Rails project, you can read, validate and use tokens in your controllers.

### Keycloak Id

If you identify users using their Keycloak Id, this value can be read from your controllers using `Keycloak::Helper.current_user_id(request.env)`. 

```ruby
class AuthenticatedController < ApplicationController

  def user
    keycloak_id = Keycloak::Helper.current_user_id(request.env)
    User.active.find_by(keycloak_id: keycloak_id)
  end
end
```

### Roles

`Keycloak::Helper.current_user_roles` can be use against a Rails request to read user's roles.

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
    Keycloak::Helper.current_user_roles(request.env)
  end
end
```

### Create an URL where the token must be passed via query string

`Keycloak::Helper.create_url_with_token` method can be used to build an url from another, by adding a token as query string.

```ruby
def example
  Keycloak::Helper.create_url_with_token("https://api.pouet.io/api/more-pouets", "myToken")
end
```

This should output `https://api.pouet.io/api/more-pouets?authorizationToken=myToken`.


### Accessing Keycloak Service

A lazy-loaded service Keycloak::Service can be accessed using `Keycloak.service`.
For instance, to read a provided token:
```ruby
class RenderTokenController < ApplicationController
  def show
    uri     = request.env["REQUEST_URI"]
    headers = request.env
    token   = Keycloak.service.read_token(uri, headers)
    render json: { token: token }, status: :ok
  end
end
```

## How to execute tests

From the `keycloak-rails-api` directory:

```
  $ docker build . -t keycloak-rails-api:test
  $ docker run -v `pwd`:/usr/src/app/ keycloak-rails-api:test bundle exec rspec spec
```
