FROM ruby:2.7.5-slim-bullseye

RUN apt-get update -qq && apt-get install -y build-essential git ruby-dev && apt-get clean && \
  mkdir -p /usr/src/app/lib/keycloak-api-rails

WORKDIR /usr/src/app

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
COPY keycloak-api-rails.gemspec /usr/src/app/
COPY lib/keycloak-api-rails/version.rb /usr/src/app/lib/keycloak-api-rails/
# RUN bundle install
COPY . /usr/src/app
# RUN bundle install