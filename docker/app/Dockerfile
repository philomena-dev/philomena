# Welcome 👋! This is the image used for local development and CI.
# It includes the tools that are required to format, lint, build and run Philomena.

FROM elixir:1.18.3-alpine AS app

RUN apk add curl

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
ARG USER
ENV USER=$USER

ARG WORKSPACE
ENV WORKSPACE=$WORKSPACE

# docker-compose configures a bind-mount of the repo root dir to $WORKSPACE
ENV PATH=$PATH:/home/$USER/.cargo/bin
ENV PATH=$PATH:$WORKSPACE/scripts/path
ENV PATH=$PATH:$WORKSPACE/node_modules/.bin

RUN mkdir -p $WORKSPACE

WORKDIR $WORKSPACE

# The UID of 1000 is the default for most Linux distributions, which should make
# this user map to the default user on the host system for bind-mounted volumes.
#
# However, if you are running this in a devcontainer via VSCode, then it'll update
# the UID/GID of this user to match the UID/GID of the user on the host automatically:
# https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_specifying-the-default-container-user
RUN adduser $USER --uid 1000 --shell /bin/zsh --disabled-password \
    # Allow paswordless sudo for the non-root user
    && echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER

USER $USER

RUN sudo chown -R "$(id -u):$(id -g)" . \
    # Precreate the cache directories. This way they are owned by the non-root when
    # volumes are mounted at these locations.
    && mkdir -p ./.cargo ./_build ./deps ./priv/native

EXPOSE 5173

CMD ["./docker/app/run-development"]

# === Devcontainer ===
#
# This stage extends the `app` image with devcontainer-specific tools and configs.
FROM app AS devcontainer

# The base image uses a non-root user, but we need to switch to root for a brief
# moment to install some additional dependencies.
USER root

# This env variable is used by the scripts to detect if they are running in a
# devcontainer
ENV DEVCONTAINER=1

RUN --mount=source=./scripts,target=./scripts ./scripts/install/typos.sh
RUN --mount=source=./scripts,target=./scripts ./scripts/install/shellcheck.sh

RUN apk add --update \
    # Required by Caddyfile LSP for autoformatting
    caddy \
    # Fzf provides better search history navigation via Ctrl+R
    fzf \
    docker-cli-compose \
    # Required for the Github Pull Requests VSCode extension to fetch via git
    # SSH URLs
    openssh \
    # Needed for the `usermod` command
    shadow \
    zsh \
    zsh-syntax-highlighting

USER $USER

# Install oh-my-zsh
RUN curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh

# Install some zsh plugins
RUN git clone https://github.com/popstas/zsh-command-time.git ~/.oh-my-zsh/custom/plugins/command-time
RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
RUN git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Store the history in a specific location that is persisted via a volume
RUN mkdir $HOME/shell-history && touch $HOME/shell-history/history

RUN ln -sf $WORKSPACE/.devcontainer/common/.zshrc $HOME/.zshrc

ENTRYPOINT ["./.devcontainer/common/init-container.sh"]

# Make sure the process doesn't exit to keep the container alive
CMD ["sleep", "infinity"]
