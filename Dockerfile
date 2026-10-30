# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim-bookworm AS base
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    ca-certificates curl libvips42 postgresql-client tzdata \
    && rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential git libpq-dev libyaml-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf /usr/local/bundle/cache
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

FROM base
RUN groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails
RUN mkdir -p /rails/storage /rails/tmp/pids && chown -R rails:rails /rails/storage /rails/tmp
USER rails:rails
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
