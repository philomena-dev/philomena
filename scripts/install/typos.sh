#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TOOL_VERSION=${TOOL_VERSION:-1.31.1}

url="https://github.com/crate-ci/typos/releases/download/v$TOOL_VERSION/typos-v$TOOL_VERSION-x86_64-unknown-linux-musl.tar.gz"

fetch "$url" | tar --gzip -xC "$tools_dir" ./typos

step chmod +x "$tools_dir/typos"

step typos --version
