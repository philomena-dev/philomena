#!/usr/bin/env bash
# Script to initialize the repo for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function fetch {
  local url="$1"
  step curl --fail --silent --show-error --location --retry 5 --retry-all-errors "$url"
}

function fetch_github_artifact_url {
  local owner_and_repo="$1"
  local artifact_pattern="$2"

  fetch "https://api.github.com/repos/$owner_and_repo/releases/latest" \
    | grep browser_download_url \
    | grep "$artifact_pattern" \
    | cut --delimiter '"' --fields 4
}

tools_dir="$(dirname "${BASH_SOURCE[0]}")/../.tools"

step mkdir -p "$tools_dir"

# Install `typos` CLI
typos_url=$(fetch_github_artifact_url crate-ci/typos x86_64-unknown-linux-musl)
fetch "$typos_url" | tar -xzC "$tools_dir" ./typos
step chmod +x "$tools_dir/typos"

# Install `shellcheck` CLI
shellcheck_url=$(fetch_github_artifact_url koalaman/shellcheck linux.x86_64)
shellcheck_dir="$(basename "$shellcheck_url" .linux.x86_64.tar.xz)"
fetch "$shellcheck_url" | tar --xz --strip-components=1 -xC "$tools_dir" "$shellcheck_dir/shellcheck"
step chmod +x "$tools_dir/shellcheck"

# Install prettier (see top-level package.json)
step npm ci --ignore-scripts

# Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit
