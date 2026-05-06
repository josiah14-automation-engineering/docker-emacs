#!/usr/bin/env bash
set -euo pipefail

MARCH="${MARCH:-skylake}"
MTUNE="${MTUNE:-skylake}"

docker build . -t "josiah14/emacs:30.2-${MARCH}-ubuntu-24.04-dev" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)" \
  --build-arg MARCH="${MARCH}" \
  --build-arg MTUNE="${MTUNE}"
