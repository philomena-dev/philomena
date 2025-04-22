ARG CADDY_VERSION="2.10.0"
ARG CADDY_FS_S3_VERSION=v0.10.0

FROM caddy:$CADDY_VERSION-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/sagikazarmark/caddy-fs-s3@${CADDY_FS_S3_VERSION}

FROM caddy:$CADDY_VERSION-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

EXPOSE 80

# Create a non-root user to avoid polluting the bind-mounted directories with
# root-owned files on the host machine.
# ARG USER=philomena
# ENV USER=$USER

# # The UID of 1000 is the default for most Linux distributions, which should make
# # this user map to the default user on the host system for bind-mounted volumes.
# RUN adduser $USER --uid 1000 --disabled-password

# USER $USER
