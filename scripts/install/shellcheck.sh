#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TOOL_VERSION=${TOOL_VERSION:-0.10.0}

stem="shellcheck-v$TOOL_VERSION"
url=https://github.com/koalaman/shellcheck/releases/download/v$TOOL_VERSION/$stem.linux.x86_64.tar.xz

fetch "$url" | tar --xz --strip-components=1 -xC "$tools_dir" "$stem/shellcheck"

step chmod +x "$tools_dir/shellcheck"

step shellcheck --version
