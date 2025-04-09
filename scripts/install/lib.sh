#!/usr/bin/env bash

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

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

tools_dir=${TOOLS_DIR:-"$repo/.tools"}

# Add `.tools` to the PATH to make the tools installed via `init.sh` available
# to the scripts.
export PATH="$tools_dir:$PATH"


step mkdir -p "$tools_dir"
