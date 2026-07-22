#!/usr/bin/env bash
set -euo pipefail

USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
GUIX_VERSION="$(grep -m1 '^ARG GUIX_VERSION=' "${SCRIPT_DIR}/Dockerfile" | cut -d= -f2)"

if [[ "${1:-}" == "--test" || "${1:-}" == "-t" ]]; then
  docker run --rm \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    "josiah14/guix:${GUIX_VERSION}-ubuntu-26.04" \
    bats "/home/${USER}/work/smoketest.bats"
else
  docker run --rm -it \
    --name "guix-source-aarch64" \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    -w "/home/${USER}/work" \
    "josiah14/guix:${GUIX_VERSION}-ubuntu-26.04"
fi
