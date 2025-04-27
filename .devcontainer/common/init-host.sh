#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"

script_dir="$(dirname "${BASH_SOURCE[0]}")"

# This is a workaround script that creates the `.env` file with some values
# specific to the host machine required by our Dockerfile and
# docker-compose.yml.
#
# The core problem is that `docker-compose` doesn't allow for shell expressions
# in the `.env` file, so we have to generate it.
#
# It's really sad that this is necessary. Related:
# https://stackoverflow.com/a/62123142/9259330

dotenv_path="$script_dir/.env"

dotenv_content=$(cat << EOF
HOST_WORKSPACE='$(realpath "$script_dir/../..")'
CONTAINER_WORKSPACE=/home/philomena/philomena
EOF
)

echo "$dotenv_content" > "$dotenv_path"

info "Created a file '$dotenv_path' with contents:\n$dotenv_content"
