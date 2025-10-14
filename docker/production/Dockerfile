FROM elixir:1.18.4-alpine

LABEL org.opencontainers.image.authors="liamwhite <liamwhite@users.noreply.github.com>, Nighty <luna@nighty.cloud>, and contributors"
LABEL org.opencontainers.image.description="The official Philomena Docker image intended for production use."
LABEL org.opencontainers.image.source="https://github.com/philomena-dev/philomena"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

WORKDIR /var/www/philomena

ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV PATH=$PATH:/root/.cargo/bin

# Install dependencies and build tools
RUN apk update --allow-untrusted \
    && apk add build-base git npm nodejs postgresql17-client wget rust cargo --allow-untrusted \
    && mix local.hex --force \
    && mix local.rebar --force

# Copy repo files into the image
COPY . /var/www/philomena

# Install and compile assets
RUN cd /var/www/philomena/assets \
    && NODE_ENV=development npm install \
    && npm run deploy

# Build the application
RUN cd /var/www/philomena \
    && mix deps.get \
    && mix release --overwrite

# Digest and copy static assets.
RUN mix phx.digest -o /var/www/philomena/_build/prod/rel/philomena/lib/philomena-*/priv/static \
    && mkdir -p /var/www/philomena/priv/static \
    && cp -r /var/www/philomena/_build/prod/rel/philomena/lib/philomena-*/priv/static/* /var/www/philomena/priv/static \
    && ln -sf /var/www/philomena/_build/prod/rel/philomena /usr/local/share/philomena \
    && ln -sf /var/www/philomena/_build/prod/rel/philomena/bin/philomena /usr/local/bin/philomena

# Cleanup build tools and unnecessary files
RUN apk del git build-base npm nodejs wget rust cargo \
    && rm -rf /tmp/philomena \
    && rm -rf /var/www/philomena/.git \
    && rm -rf /var/www/philomena/.cargo \
    && rm -rf /var/www/philomena/docker \
    && rm -rf /var/www/philomena/assets/node_modules \
    && rm -f /sbin/apk \
    && rm -rf /etc/apk /lib/apk /usr/share/apk /var/lib/apk

COPY docker/production/run-cron /usr/local/bin/run-cron
COPY docker/production/run-cron-daily /usr/local/bin/run-cron-daily
COPY docker/production/run-production /usr/local/bin/run-production
COPY docker/production/purge-cache /usr/local/bin/purge-cache

EXPOSE 4000-4002

CMD ["/usr/local/bin/run-production"]
