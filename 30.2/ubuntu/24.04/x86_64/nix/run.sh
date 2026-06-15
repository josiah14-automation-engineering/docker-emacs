#!/usr/bin/env bash
set -euo pipefail

USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
NIX_VERSION="$(grep -m1 '^ARG NIX_VERSION=' "${SCRIPT_DIR}/Dockerfile" | cut -d= -f2)"

if [[ "${1:-}" == "--test" || "${1:-}" == "-t" ]]; then
  docker run --rm \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    "josiah14/nix:${NIX_VERSION}-ubuntu-24.04" \
    bats "/home/${USER}/work/smoketest.bats"
else
  docker run --rm -it \
    --name "nix-source" \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    -w "/home/${USER}/work" \
    "josiah14/nix:${NIX_VERSION}-ubuntu-24.04"
fi
