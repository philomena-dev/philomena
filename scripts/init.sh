#!/usr/bin/env bash
# Script to initialize the repo for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Install the pre-commit hook. It's a symlink, to make sure it stays always up-to-date.
step ln -sf ../../.githooks/pre-commit .git/hooks/pre-commit

step cd docker/toolbox
