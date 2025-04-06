#!/usr/bin/env bash

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# `curl` wrapper with better defaults
function fetch {
  local url="$1"
  step curl --fail --silent --show-error --location --retry 5 --retry-all-errors "$url"
}

step mkdir -p "$tools_dir"
