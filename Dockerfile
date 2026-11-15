# syntax=docker/dockerfile:1
# frozen_string_literal: true

# ---- Base image ----
FROM ruby:4.0.9-slim-bookworm AS base

# Install Node.js + system build/sqlite deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      gnupg \
      build-essential \
      libsqlite3-dev \
      git \
      chromium \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Gems ----
FROM base AS gems

# Copy only the manifest files first for layer caching
COPY doorloop-app.gemspec ./
COPY lib/doorloop_app/version.rb lib/doorloop_app/version.rb
COPY Gemfile Gemfile.lock .ruby-version ./

RUN bundle config set --local without "development" \
    && bundle config set --local frozen true \
    && bundle install --jobs "$(nproc)" --retry 3

# ---- Local agent-browser ----
FROM gems AS browser

COPY package.json package-lock.json ./
RUN npm ci --omit=dev
RUN ./node_modules/.bin/agent-browser --version

# ---- Final image ----
FROM browser AS app

# Copy full application source
COPY . .

# Data volume: Chrome profile + SQLite DB persist here
RUN mkdir -p /data && ln -s /data /root/.agent-browser
VOLUME /data

# Runtime environment
ENV DOORLOOP_HEADLESS=true \
    DOORLOOP_BROWSER_EXECUTABLE=/usr/bin/chromium \
    DOORLOOP_BROWSER_ARGS="--no-sandbox,--disable-setuid-sandbox" \
    DOORLOOP_PROFILE_DIR=/data/chrome-profile \
    DOORLOOP_DB_PATH=/data/doorloop.sqlite3 \
    DOORLOOP_API_REGISTRY=/data/api_registry.json

ENTRYPOINT ["bundle", "exec", "bin/doorloop"]
CMD ["server"]
