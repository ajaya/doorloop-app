# syntax=docker/dockerfile:1
# frozen_string_literal: true

# ---- Base image ----
FROM ruby:4.0.1-slim-bookworm AS base

# Install Node.js + system build/sqlite deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      gnupg \
      build-essential \
      libsqlite3-dev \
      git \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---- Gems ----
FROM base AS gems

# Copy only the manifest files first for layer caching
COPY doorloop-mcp.gemspec ./
COPY lib/doorloop_mcp/version.rb lib/doorloop_mcp/version.rb
COPY Gemfile Gemfile.lock* ./

RUN bundle config set --local without "development" \
    && bundle install --jobs "$(nproc)" --retry 3

# ---- Node / Playwright ----
FROM gems AS playwright

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Install Chromium browser binary + all OS-level dependencies
RUN npx playwright install chromium --with-deps

# ---- Final image ----
FROM playwright AS app

# Copy full application source
COPY . .

# Data volume: Chrome profile + SQLite DB persist here
RUN mkdir -p /data
VOLUME /data

# Runtime environment
ENV DOORLOOP_HEADLESS=true \
    DOORLOOP_PROFILE_DIR=/data/chrome-profile \
    DOORLOOP_DB_PATH=/data/doorloop.sqlite3

ENTRYPOINT ["bundle", "exec", "bin/doorloop"]
CMD ["server"]
