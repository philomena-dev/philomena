FROM elixir:1.19.2-alpine AS builder

WORKDIR /tmp/philomena

ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV PATH=$PATH:/root/.cargo/bin

# Install dependencies and build tools
RUN apk update --allow-untrusted \
    && apk add build-base git npm nodejs wget rust cargo --allow-untrusted \
    && mix local.hex --force \
    && mix local.rebar --force

# Copy repo files into the image
COPY . /tmp/philomena

# Install and compile assets
RUN cd /tmp/philomena/assets \
    && NODE_ENV=development npm install \
    && npm run deploy

# Build the application and create symlinks for easier access
RUN cd /tmp/philomena \
    && mix deps.get \
    && mix release --overwrite

# Digest and copy static assets
RUN mix phx.digest -o /tmp/philomena/_build/prod/rel/philomena/lib/philomena-*/priv/static

FROM alpine:3.22

LABEL org.opencontainers.image.authors="liamwhite <liamwhite@users.noreply.github.com>, Nighty <luna@nighty.cloud>, and contributors"
LABEL org.opencontainers.image.description="The official Philomena Docker image intended for production use."
LABEL org.opencontainers.image.source="https://github.com/philomena-dev/philomena"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

# Install runtime dependencies
RUN apk update \
    && apk add --no-cache libncursesw libstdc++ libgcc

# Set up a non-root user to run the application
RUN addgroup -g 1000 -S philomena \
    && adduser -u 1000 -S philomena -G philomena

# Copy the finished release and the config (because of .json files) from the builder stage...
COPY --from=builder --chown=1000:1000 /tmp/philomena/_build/prod/rel/philomena /srv/philomena
COPY --from=builder --chown=1000:1000 /tmp/philomena/config /srv/philomena/config

# ...and the production scripts from the repository
COPY --chown=1000:1000 docker/production/run-cron /usr/local/bin/run-cron
COPY --chown=1000:1000 docker/production/run-cron-daily /usr/local/bin/run-cron-daily
COPY --chown=1000:1000 docker/production/run-production /usr/local/bin/run-production
COPY --chown=1000:1000 docker/production/purge-cache /usr/local/bin/purge-cache

# A "philomena" symlink for easier access
RUN ln -sf /srv/philomena/bin/philomena /usr/local/bin/philomena

USER philomena

# Create the static assets symlink as the philomena user
RUN ln -sf /srv/philomena/lib/philomena-*/priv/static /srv/philomena/static

WORKDIR /srv/philomena

EXPOSE 4000-4002

CMD ["/usr/local/bin/run-production"]
