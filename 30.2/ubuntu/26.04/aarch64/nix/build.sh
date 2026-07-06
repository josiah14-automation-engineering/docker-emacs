#!/usr/bin/env bash
set -euo pipefail

NIX_VERSION="$(grep -m1 '^ARG NIX_VERSION=' Dockerfile | cut -d= -f2)"

docker build . \
  --ulimit nofile=262144:262144 \
  -t "josiah14/nix:${NIX_VERSION}-ubuntu-26.04" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)"
