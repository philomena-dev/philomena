#!/usr/bin/env bash
# Script to initialize the repo for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# No need for a pre-commit hook on CI. Moreover it fails because our CI runs
# on behalf of the `root` user, and thus .git is root-owned.
if [[ "${CI:-}" != "true" ]]; then
    # Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
    step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit
fi
