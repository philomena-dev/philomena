#!/usr/bin/env bash
# Script to start the docker-compose stack for development.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Set this env var to `1` if you want to drop your current postgres DB and
# reseed the DB from scratch again.
drop_db=${drop_db:-0}


if [[ "$drop_db" == "1" ]]; then
  info "Dropping databases..."

  # It's important to stop all containers to make sure they shut down cleanly.
  # Also, `valkey` stores its data in RAM, so to drop its "database" we need
  # to stop its container.
  step docker compose down

  # We aren't using `--volumes` parameter with the `docker compose down` because
  # we don't want to delete the build caches, which are also stored in volumes.
  step docker volume rm \
    philomena_postgres_data \
    philomena_opensearch_data
fi

step docker compose up --no-log-prefix
