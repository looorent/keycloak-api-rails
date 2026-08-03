# frozen_string_literal: true

# Test helpers for the applications that authenticate their requests with this library.
#
# This file is *not* loaded by "keycloak-api-rails": it has to be required explicitly, so that
# nothing it defines can end up in a production process.
#
#   # spec/rails_helper.rb
#   require "keycloak-api-rails/testing"
#
#   RSpec.configure do |config|
#     config.include KeycloakApiRails::Testing::Helpers
#     config.before(:suite) { KeycloakApiRails::Testing.stub_public_keys! }
#   end
#
# Requests can then be authenticated without a running Keycloak, and without configuring
# 'server_url' or 'realm_id':
#
#   get "/me", headers: keycloak_auth_headers(sub: user.keycloak_id, roles: ["admin"])

require_relative "../keycloak-api-rails"
require "securerandom"

module KeycloakApiRails
  module Testing

    KEY_SIZE                    = 2048
    KEY_ID                      = "keycloak-api-rails-testing"
    ALGORITHM                   = :RS256
    DEFAULT_VALIDITY_IN_SECONDS = 3600

    # Returns the public keys forged by this module, instead of fetching them from a Keycloak server.
    class PublicKeyResolver
      def initialize(public_keys)
        @public_keys = public_keys
      end

      def find_public_keys(realm_id = nil)
        @public_keys
      end
    end

    MONITOR = Monitor.new

    class << self
      # The RSA key pair used to sign the tokens forged by this module. It is generated once per
      # process: generating a key is by far the slowest operation of a test suite that uses tokens.
      def private_key
        MONITOR.synchronize { @private_key ||= OpenSSL::PKey::RSA.generate(KEY_SIZE) }
      end

      def signing_key
        MONITOR.synchronize { @signing_key ||= JSON::JWK.new(private_key, kid: KEY_ID) }
      end

      def public_keys
        MONITOR.synchronize { @public_keys ||= JSON::JWK::Set.new(JSON::JWK.new(private_key.public_key, kid: KEY_ID)) }
      end

      # Makes the library validate the tokens forged by this module. Assigning
      # 'KeycloakApiRails.public_key_resolver = nil' restores the regular resolver.
      def stub_public_keys!
        KeycloakApiRails.public_key_resolver = PublicKeyResolver.new(public_keys)
      end

      # Forges a signed token, similar to the ones emitted by Keycloak. Every claim this library
      # reads has a dedicated parameter; any other claim can be passed through 'claims', which is
      # also how the attributes declared in 'config.custom_attributes' are set.
      def token_for(sub: SecureRandom.uuid,
                    email: nil,
                    locale: nil,
                    authorized_party: nil,
                    roles: [],
                    resource_roles: {},
                    issued_at: Time.now,
                    expires_at: nil,
                    claims: {})
        payload = {
          "sub"    => sub,
          "email"  => email,
          "locale" => locale,
          "azp"    => authorized_party,
          "iat"    => issued_at.to_i,
          "exp"    => (expires_at || (issued_at.to_i + DEFAULT_VALIDITY_IN_SECONDS)).to_i
        }.reject { |_, value| value.nil? }

        payload["realm_access"]    = { "roles" => roles.map(&:to_s) } unless roles.nil? || roles.empty?
        payload["resource_access"] = build_resource_access(resource_roles) unless resource_roles.nil? || resource_roles.empty?

        unless claims.key?(:iss) || claims.key?("iss")
          config_realm_id = KeycloakApiRails.config.realm_id
          realm_id = config_realm_id.is_a?(String) ? config_realm_id : "master"
          issuer_url = KeycloakApiRails.config.issuer_url || KeycloakApiRails.config.server_url
          payload["iss"] = File.join(issuer_url.to_s, "realms", realm_id)
        end

        claims.each { |name, value| payload[name.to_s] = value }

        JSON::JWT.new(payload).sign(signing_key, ALGORITHM).to_s
      end

      # The 'Authorization' header a client would send, e.g. { "Authorization" => "Bearer eyJ0..." }.
      # It accepts the same parameters as '.token_for'.
      def auth_headers_for(**options)
        { "Authorization" => "Bearer #{token_for(**options)}" }
      end

      private

      def build_resource_access(resource_roles)
        resource_roles.inject({}) do |resource_access, (name, roles)|
          resource_access[name.to_s] = { "roles" => Array(roles).map(&:to_s) }
          resource_access
        end
      end
    end

    # Meant to be included in a test suite, e.g. 'config.include KeycloakApiRails::Testing::Helpers'.
    module Helpers
      def keycloak_token(**options)
        KeycloakApiRails::Testing.token_for(**options)
      end

      def keycloak_auth_headers(**options)
        KeycloakApiRails::Testing.auth_headers_for(**options)
      end
    end
  end
end
