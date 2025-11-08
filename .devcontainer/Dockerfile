FROM elixir:1.19.1-alpine

ARG CONTAINER_WORKSPACE

ENV PATH=$CONTAINER_WORKSPACE/node_modules/.bin:$PATH
ENV PATH=$CONTAINER_WORKSPACE/scripts/path:$PATH
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR $CONTAINER_WORKSPACE

RUN apk add \
    bash \
    build-base \
    git \
    npm \
    nodejs \
    curl \
    wget \
    docker-cli-compose \
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

# Some routines need to be run every time the container starts, because they
# need to modify the bind-mounted volume.
ENTRYPOINT ["./.devcontainer/init-container.sh"]

# Make sure the process doesn't exit to keep the container alive
CMD ["sleep", "infinity"]
