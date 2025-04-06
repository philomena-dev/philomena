#!/usr/bin/env bash
# Script to initialize the repo for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "$repo/scripts/install/typos.sh"
step "$repo/scripts/install/shellcheck.sh"

# Install prettier (see top-level package.json)
step npm ci --ignore-scripts
step npx prettier --version

# Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit
