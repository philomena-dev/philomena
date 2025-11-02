FROM elixir:1.19.1-alpine

RUN apk add bash inotify-tools build-base git npm nodejs postgresql17-client wget rust cargo \
    && mix local.hex --force \
    && mix local.rebar --force

# docker-compose configures a bind-mount of the repo root dir to /srv/philomena
ENV PATH=$PATH:/root/.cargo/bin:/srv/philomena/docker/app
EXPOSE 5173
CMD run-development
