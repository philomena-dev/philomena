#!/usr/bin/env bash

set -euo pipefail

script_dir="$(dirname "${BASH_SOURCE[0]}")"

# This is a workaround script that creates the `.env` file with some values specific
# to the host machine required by our Dockerfile and docker-compose.yml.
#
# The core problem is that `docker-compose` doesn't allow for shell expressions in
# the `.env` file, so we have to code-generate.
#
# It's really sad that this is necessary, but that's the solution.
# Related: https://stackoverflow.com/a/62123142/9259330

user=$(whoami)

# Codepaces are using the `root` user by default.
if [[ "$user" == "root" ]]; then
  user=philomena
fi

if [[ -v CODESPACES ]]; then
  # Codespaces are using the `codespace` user by default.
  workspace="/workspaces/${CODESPACE_NAME}"
else
  workspace=$(realpath "$script_dir/../..")
fi


cat > "$script_dir/.env" << EOF
WORKSPACE='$workspace'
USER='$user'
EOF
