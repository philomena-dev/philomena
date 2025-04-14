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

export tools_dir="/usr/local/bin"
