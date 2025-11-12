# Workaround for alpine packages not having PostgreSQL 18 client yet.
FROM postgres:18.0-alpine as pg

FROM elixir:1.19.1-alpine

# TODO: remove this once alpine has the postgresql18-client package
# Alternatively: consider if we want to keep using this workaround long-term
COPY --from=pg /usr/local/bin/pg_dump /usr/local/bin/pg_dump

ARG CONTAINER_WORKSPACE=/srv/philomena

ENV PATH=$CONTAINER_WORKSPACE/node_modules/.bin:$PATH
ENV PATH=$CONTAINER_WORKSPACE/scripts/path:$PATH
ENV PATH=$CONTAINER_WORKSPACE/docker/app:$PATH
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR $CONTAINER_WORKSPACE

RUN apk add \
    bash \
    inotify-tools \
    build-base \
    git \
    npm \
    nodejs \
    postgresql17-client \
    curl \
    wget \
    docker-cli-compose \
    docker-cli-buildx \
    # Required by Caddyfile LSP for autoformatting
    caddy \
    # Required by Github Pull Requests VSCode extension to fetch via git SSH URLs
    openssh

# The default `cargo` and `rust` packages in Alpine repo don't include important
# rust dev components like `rust-src` (std lib sources), `rustfmt`, `clippy`, etc.
# In any case, it's much better to use rustup for rust toolchain management.
# Also, this lives in a separate RUN statement to cache this step separately, as
# it's quite slow to install.
RUN --mount=source=./scripts/lib.sh,target=./scripts/lib.sh \
    --mount=source=./scripts/install/rust.sh,target=./scripts/install/rust.sh \
    --mount=source=./rust-toolchain.toml,target=./rust-toolchain.toml \
    ./scripts/install/rust.sh

RUN --mount=source=./scripts,target=./scripts \
    ./scripts/install/shellcheck.sh \
    && ./scripts/install/typos.sh

# `/shell-history` dir is persisted across container rebuilds/restarts
ENV HISTFILE=/shell-history/history

ENTRYPOINT ["run"]
CMD ["run-development"]
