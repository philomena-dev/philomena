# Welcome 👋! This is the image used for local development and CI.
# It includes the tools that are required to format, lint, build and run Philomena.

FROM elixir:1.18.3-alpine AS app

# This env variable is used by the scripts to detect if they are running in a
# container and thus don't need to forward the execution to the devcontainer.
ENV CONTAINER=true

RUN apk add curl

# Not using the `ADD` instruction here. For some reason it fails with a 403
# error when building on Github CodeSpaces that way (yeah, weird).
RUN curl -fsSL https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/6.1 -o /tmp/ffmpeg_version.json

RUN ( \
      echo "https://github.com/philomena-dev/prebuilt-ffmpeg/raw/master"; \
      cat /etc/apk/repositories \
    ) > /tmp/repositories \
    && cp /tmp/repositories /etc/apk/repositories \
    && apk add --update \
      bash \
      inotify-tools \
      build-base \
      git \
      ffmpeg \
      ffmpeg-dev \
      npm \
      nodejs \
      file-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      gifsicle \
      optipng \
      libjpeg-turbo-utils \
      librsvg \
      rsvg-convert \
      imagemagick \
      postgresql17-client \
      wget \
      rust \
      cargo \
      sudo \
    && mix local.hex --force \
    && mix local.rebar --force

RUN curl -fsSL https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master -o /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

RUN curl -fsSL https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master -o /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

# Create a non-root user to avoid polluting the bind-mounted directories with
# root-owned files on the host machine.
ENV USER=philomena
ENV HOME=/home/$USER

# The UID of 1000 is the default for most Linux distributions, which should make
# this user map to the default user on the host system for bind-mounted volumes.
#
# However, if you are running this in a devcontainer via VSCode, then it'll update
# the UID/GID of this user to match the UID/GID of the user on the host automatically:
# https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_specifying-the-default-container-user
RUN adduser "$USER" --uid 1000 --shell /bin/zsh --disabled-password \
    # Allow paswordless sudo for the non-root user
    && echo "$USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER"

USER $USER

# docker-compose configures a bind-mount of the repo root dir to $CONTAINER_WORKSPACE
ENV CONTAINER_WORKSPACE=$HOME/philomena
WORKDIR $CONTAINER_WORKSPACE

RUN sudo chown -R "$(id -u):$(id -g)" . \
    # Precreate the cache directories. This way they are owned by the non-root when
    # volumes are mounted at these locations.
    && mkdir -p $HOME/.tools ./.cargo ./_build ./deps ./priv/native

ENV PATH="$PATH:$HOME/.cargo/bin"
ENV PATH="$PATH:$HOME/.tools"
ENV PATH="$PATH:$CONTAINER_WORKSPACE/docker/app"
ENV PATH="$PATH:$CONTAINER_WORKSPACE/scripts/path"
ENV PATH="$PATH:$CONTAINER_WORKSPACE/node_modules/.bin"

EXPOSE 5173

CMD ["run-development"]

# ====================
# === Devcontainer ===
# ====================
#
# This stage extends the `app` image with devcontainer-specific tools and configs.
FROM app AS devcontainer

# Store the history in a specific location that is persisted via a volume
ENV HISTFILE="$HOME/shell-history/history"
RUN mkdir "$(dirname $HISTFILE)" && touch "$HISTFILE"

RUN sudo apk add \
    # Required by Caddyfile LSP for autoformatting
    caddy \
    # Fzf provides better search history navigation via Ctrl+R
    fzf \
    # Required for the Github Pull Requests VSCode extension to fetch via git
    # SSH URLs
    openssh \
    # Needed for the `usermod` command
    shadow \
    shellcheck=0.10.0-r1 \
    zsh

RUN sudo apk add --repository https://dl-cdn.alpinelinux.org/alpine/edge/community \
    # This version of `docker-compose` contains a fix for the following annoying
    # terminal flickering bug: https://github.com/docker/compose/issues/12435
    docker-cli-compose=2.35.1-r0 \
    # Use the bleeding edge of `typos`. Its dictionary is often updated
    typos=1.31.1-r0

ARG OMZ=./.devcontainer/shell/oh-my-zsh.sh
RUN --mount=source=./scripts,target=./scripts --mount=source=$OMZ,target=$OMZ $OMZ

RUN ln -sf "$CONTAINER_WORKSPACE/.devcontainer/shell/.zshrc" "$HOME/.zshrc"

ENTRYPOINT ["./.devcontainer/init-container.sh"]

# Check for the presence of a special marker file that indicates that the
# container has been initialized. Use a big `--interval` to "disable"
# healthchecks after initialization completes.
#
# Also, don't be fooled - docker dosn't interpolate env vars in the CMD exec
# form, so we explicitly use `bash -c` to expand the `$HOME` variable.
HEALTHCHECK --start-period=10s --start-interval=0.5s --retries=1 --interval=9999h \
    CMD [ "bash", "-c", "test -f $HOME/.initialized" ]

# Make sure the process doesn't exit to keep the container alive
CMD ["sleep", "infinity"]
