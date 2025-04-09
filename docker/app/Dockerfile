# Welcome 👋! This is the image used for local development and CI.
# It includes the tools that are required to format, lint, build and run Philomena.

FROM elixir:1.18.3-alpine AS base

RUN apk add --no-cache \
  bash \
  curl

ENV TOOLS_DIR=/tools

FROM base AS typos
RUN --mount=source=.,dst=./repo ./repo/scripts/install/typos.sh

FROM base AS shellcheck
RUN --mount=source=.,dst=./repo ./repo/scripts/install/shellcheck.sh

FROM base

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/6.1 /tmp/ffmpeg_version.json
RUN (echo "https://github.com/philomena-dev/prebuilt-ffmpeg/raw/master"; cat /etc/apk/repositories) > /tmp/repositories \
    && cp /tmp/repositories /etc/apk/repositories \
    && apk update --allow-untrusted \
    && apk add --allow-untrusted \
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

ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

# docker-compose configures a bind-mount of the repo root dir to /srv/philomena
ENV PATH=$PATH:/srv/philomena/docker/app
ENV PATH=$PATH:$TOOLS_DIR
ENV PATH=$PATH:/root/.cargo/bin

COPY --from=typos      $TOOLS_DIR $TOOLS_DIR
COPY --from=shellcheck $TOOLS_DIR $TOOLS_DIR

EXPOSE 5173
CMD ["run-development"]
