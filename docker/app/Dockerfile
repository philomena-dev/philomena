# Workaround for alpine packages not having PostgreSQL 18 client yet.
FROM postgres:18.0-alpine as pg

FROM elixir:1.19.2-alpine

RUN apk add bash inotify-tools build-base git npm nodejs postgresql17-client wget rust cargo \
    && mix local.hex --force \
    && mix local.rebar --force

# TODO: remove this once alpine has the postgresql18-client package
# Alternatively: consider if we want to keep using this workaround long-term
COPY --from=pg /usr/local/bin/pg_dump /usr/local/bin/pg_dump

# docker-compose configures a bind-mount of the repo root dir to /srv/philomena
ENV PATH=$PATH:/root/.cargo/bin:/srv/philomena/docker/app
EXPOSE 5173
CMD run-development
