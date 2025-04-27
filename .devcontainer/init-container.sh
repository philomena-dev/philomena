#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

function setup_rootless_docker {
  # Add the current user to the docker group to allow running docker commands
  # without sudo. We have to do this right at the start of the container instead
  # of the build time because the docker socket is mounted only at runtime.
  docker_gid=$(stat -c '%g' /var/run/docker.sock || true)

  if [[ "${docker_gid}" == '' ]]; then
    # Docker socket was not mounted, so nothing to do.
    return 0
  fi

  # This should never realistically happen, thus we don't bother handling this
  # situation. Handling it would require running a `socat` proxy for the socket
  if [[ "${docker_gid}" == '0' ]]; then
    warn "Can't configure rootless docker. The docker socket is owned by root"
    return 0
  fi

  # This is really annoying, but to provide sudo-less access to the docker
  # socket, we need to add the current user to the group that owns the socket.
  # Because we mount it from the host the group may have arbitrary ID that we
  # can't easily control.
  #
  # There can also be an existing group in the container with the ID of the host
  # docker socket group, which is very likely to happen given that the usual
  # docker group has ID 999 and Alpine Linux uses this GID for the `ping` group:
  # https://github.com/alpinelinux/docker-alpine/issues/323
  existing_group=$(getent group "${docker_gid}" || true)

  if [ "$existing_group" = '' ]; then
    step sudo groupadd --gid "${docker_gid}" docker-host
  else
    info "Group with the host docker socket GID already exists: ${existing_group}. Reusing it."
  fi

  user=$(whoami)

  if [ "$(id "$user" | grep -E "groups=.*(=|,)${docker_gid}\\(")" = '' ]; then
    step sudo usermod --append --groups "${docker_gid}" "$user"
  else
    info "User ${user} is already in the group ${docker_gid}. No need to add it again."
  fi
}

setup_rootless_docker
philomena init

step exec "$@"
