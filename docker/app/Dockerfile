# Welcome 👋! This is the image used for local development and CI.
# It includes the tools that are required to format, lint, build and run Philomena.

FROM elixir:1.18.3-alpine

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/6.1 /tmp/ffmpeg_version.json

RUN ( \
      echo "https://github.com/philomena-dev/prebuilt-ffmpeg/raw/master"; \
      cat /etc/apk/repositories \
    ) > /tmp/repositories \
    && cp /tmp/repositories /etc/apk/repositories \
    && apk add --update \
      bash \
      curl \
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
    && mix local.hex --force \
    && mix local.rebar --force

# Dev-only tools
RUN apk add --update \
    bottom \
    docker-cli-compose \
    # Needed for the `usermod` command
    shadow \
    sudo

ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

# Create a non-root user to avoid polluting the bind-mounted directories with
# root-owned files on the host machine.
ARG USER=philomena
ARG CONTAINER_WORKSPACE=/home/$USER/philomena

# docker-compose configures a bind-mount of the repo root dir to $REPO
ENV PATH=$PATH:/root/.cargo/bin
ENV PATH=$PATH:$CONTAINER_WORKSPACE/docker/app
ENV PATH=$PATH:$CONTAINER_WORKSPACE/scripts/path

WORKDIR $CONTAINER_WORKSPACE

RUN --mount=source=./scripts,target=./scripts ./scripts/install/typos.sh
RUN --mount=source=./scripts,target=./scripts ./scripts/install/shellcheck.sh
RUN --mount=source=./package.json,target=./package.json \
    --mount=source=./package-lock.json,target=./package-lock.json \
    npm ci --ignore-scripts

EXPOSE 5173

CMD ["run-development"]

# The UID of 1000 is the default for most Linux distributions, which should make
# this user map to the default user on the host system for bind-mounted volumes.
#
# However, if you are running this in a devcontainer via VSCode, then it'll update
# the UID/GID of this user to match the UID/GID of the user on the host automatically:
#: https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_specifying-the-default-container-user
RUN adduser $USER --uid 1000 --shell /bin/bash --disabled-password \
    && echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER

USER $USER
