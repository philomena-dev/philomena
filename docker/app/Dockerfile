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
ENV PATH=$PATH:/root/.cargo/bin

WORKDIR /app
RUN --mount=source=./scripts,target=./scripts ./scripts/install/typos.sh
RUN --mount=source=./scripts,target=./scripts ./scripts/install/shellcheck.sh
RUN --mount=source=./package.json,target=./package.json \
    --mount=source=./package-lock.json,target=./package-lock.json \
    npm ci --ignore-scripts

EXPOSE 5173

CMD ["run-development"]
