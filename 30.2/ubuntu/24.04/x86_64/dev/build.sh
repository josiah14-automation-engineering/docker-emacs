#!/usr/bin/env bash
set -euo pipefail

docker build . -t josiah14/emacs:30.2-skylake-ubuntu-24.04-dev \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)"
