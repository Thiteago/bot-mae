# syntax = docker/dockerfile:1
ARG RUBY_VERSION=3.4.1
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN useradd bot --create-home --shell /bin/bash && chown -R bot:bot /app
USER bot:bot

CMD ["bin/bot"]
