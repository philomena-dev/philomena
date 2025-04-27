#!/usr/bin/env bash
# This file is meant to be sourced by other scripts, not executed directly.
# It contains a bunch of helper functions for writing bash scripts.

# This output stream is used by subshells to send their output to the root process stdout.
global_stdout=3
eval "exec $global_stdout>&1"

# Log a message at the info level
function info {
  local message="$*"

  echo -e "\033[32;1m[INFO]\033[0m \033[0;32m$message\033[0m" >&2
}

# Log a message at the warn level
function warn {
  local message="$*"

  echo -e "\033[33;1m[WARN]\033[0m \033[0;33m$message\033[0m" >&2
}

# Log a message at the error level
function error {
  local message=$1

  echo -e "\033[31;1m[ERROR]\033[0m \033[0;31m$message\033[0m" >&2
}

# Log a message at the error level and return a non-zero status
function die {
  local message=$1

  error "$message"
  return 1
}

# Log the command and execute it
function step {
  local cmd="$1"
  if [[ $cmd == exec ]]; then
    cmd=("${@:2}")
  else
    cmd=("${@:1}")
  fi

  # If the process runs in a parallel subshell - use the TASK env var to prefix
  # its log with the task name.
  local task="${TASK:-}"

  if [[ -n $task ]]; then
    task="($task) "
  fi

  colorized_cmd=$(colorize_command "${cmd[@]}")

  echo >&$global_stdout -e "\033[32;1m$task❱\033[0m $colorized_cmd" >&2

  "$@"
}

# Returns a command with syntax highlighting
function colorize_command {
  local program=$1
  shift

  local args=()
  for arg in "$@"; do
    if [[ $arg =~ ^- ]]; then
      args+=("\033[34;1m${arg}\033[0m")
    else
      args+=("\033[0;33m${arg}\033[0m")
    fi
  done

  # On old versions of bash, for example 4.2.46 if the `args` array is empty,
  # then an `unbound variable` is thrown.
  #
  # Luckily, we don't pass commands without positional arguments to this function,
  # and we use bash >= v5. If this ever becomes a problem, you know the why.
  echo -e "\033[1;32m${program}\033[0m ${args[*]}"
}

_repo=""
function repo {
  if [[ -z $_repo ]]; then
    _repo=$(git rev-parse --show-toplevel)
  fi

  echo "$_repo"
}

# `curl` wrapper with better defaults
function fetch {
  step curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 5 \
    --retry-all-errors \
    "$@"
}

# While it's recommended to use the devcontainer setup, it's not required. Developers
# who aren't using devcontainers can still benefit from our devcontainer image. We spin up
# a "background" devcontainer for them called "philomena-devcontainer". Then, we use `docker exec`
# where we run our scripts instead. This way the scripts can use any dependencies installed
# in the devcontainer image.
function devcontainer_up {
  info "Creating the devcontainer..."

  local file
  file="$(repo)/.devcontainer/docker-compose.yml"

  set +e
  step docker compose --file "$file" up --detach --wait --build
  local status=$?
  set -e

  if [[ "$status" = "0" ]]; then
    return 0
  fi

  step docker compose --file "$file" logs

  return "$status"
}

function devcontainer_forward {
  # Make sure the devcontainer is up and running.
  if ! docker ps --all --format '{{.Names}}' | grep -wq philomena-devcontainer; then
    devcontainer_up
  fi

  local script
  script=$(realpath "$0")
  script="${script#"$(repo)/"}"

  docker exec --interactive philomena-devcontainer "$script" "$@"
}

# Re-run this script in a the devcontainer if we aren't already in one.
if [[ ! -v CONTAINER ]] && [[ ! -v FORCE_HOST ]]; then
  devcontainer_forward "$@"
  exit $?
fi
