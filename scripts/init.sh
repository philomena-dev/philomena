#!/usr/bin/env bash
# Script to initialize the repo for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# No need for a pre-commit hook on CI.
# Also, CI runs on behalf of the `root` user, and thus .git is root-owned,
# so we need to fix this, otherwise git commands report "dubious ownership".
if [[ "${CI:-}" == "true" ]]; then
    step sudo chown -R "$(id -u):$(id -g)" .
else
    # Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
    step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit
fi
