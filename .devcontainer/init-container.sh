#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

# Install prettier if not already. Required for git pre-commit hook to work.
step npm ci --ignore-scripts

# Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit

step "$@"
