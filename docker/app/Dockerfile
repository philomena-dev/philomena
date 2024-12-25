FROM elixir:1.17.2-alpine

RUN apk add inotify-tools build-base git npm nodejs postgresql16-client wget rust cargo \
    && mix local.hex --force \
    && mix local.rebar --force

COPY native/broker /tmp/broker
RUN cd /tmp/broker \
    && cargo build --release \
    && cp target/release/broker /usr/local/bin/broker

COPY docker/app/run-development /usr/local/bin/run-development
COPY docker/app/run-test /usr/local/bin/run-test
COPY docker/app/purge-cache /usr/local/bin/purge-cache
ENV PATH=$PATH:/root/.cargo/bin
EXPOSE 5173
CMD run-development
