FROM elixir:1.18.1-alpine

RUN apk add inotify-tools build-base git npm nodejs postgresql16-client wget rust cargo \
    && mix local.hex --force \
    && mix local.rebar --force

COPY docker/app/run-development /usr/local/bin/run-development
COPY docker/app/run-test /usr/local/bin/run-test
COPY docker/app/purge-cache /usr/local/bin/purge-cache
ENV PATH=$PATH:/root/.cargo/bin
EXPOSE 5173
CMD ["/usr/local/bin/run-development"]
