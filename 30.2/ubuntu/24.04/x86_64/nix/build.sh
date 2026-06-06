#!/usr/bin/env bash
set -euo pipefail

NIX_VERSION="${NIX_VERSION:-2.33.3}"

docker build . \
  --ulimit nofile=262144:262144 \
  -t "josiah14/nix:${NIX_VERSION}-ubuntu-24.04" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --build-arg NIX_VERSION="${NIX_VERSION}"
