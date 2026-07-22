#!/usr/bin/env bash
set -euo pipefail

GUIX_VERSION="$(grep -m1 '^ARG GUIX_VERSION=' Dockerfile | cut -d= -f2)"

docker build . \
  --ulimit nofile=262144:262144 \
  -t "josiah14/guix:${GUIX_VERSION}-ubuntu-24.04" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)"
