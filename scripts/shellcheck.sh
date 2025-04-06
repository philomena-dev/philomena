#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function shell_script_files {
  git ls-files "*.sh"
  git grep --files-with-matches '^#!/usr/bin/env bash'
}

mapfile -t files < <(shell_script_files "$@" | sort --unique)

step shellcheck --source-path SCRIPTDIR "${files[@]}"
