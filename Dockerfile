# Multi-stage Dockerfile producing a self-contained Elixir/Phoenix OTP release.
#
# The image tags below can be bumped to match your local toolchain; the project
# only requires Elixir ~> 1.15. Find supported tags at:
#   https://hub.docker.com/r/hexpm/elixir/tags
ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV="prod"

# Install mix dependencies (cached layer)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Compile-time config first so dependency recompilation is cached well
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets and the application
RUN mix assets.deploy
RUN mix compile

# Runtime config + release assembly
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

# ---- Runtime stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

# Copy the assembled release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/bravo ./

USER nobody

EXPOSE 4000

# `bin/server` sets PHX_SERVER=true and boots the endpoint.
CMD ["/app/bin/server"]
