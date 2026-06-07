FROM elixir:1.20.0-alpine

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
    postgresql18-client \
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
COPY scripts scripts
COPY rust-toolchain.toml rust-toolchain.toml

RUN ./scripts/install/rust.sh \
    && ./scripts/install/shellcheck.sh \
    && ./scripts/install/typos.sh

# `/shell-history` dir is persisted across container rebuilds/restarts
ENV HISTFILE=/shell-history/history

ENTRYPOINT ["run"]
CMD ["run-development"]
