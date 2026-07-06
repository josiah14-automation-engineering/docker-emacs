#!/usr/bin/env bash
set -euo pipefail

MCPU="${MCPU:-apple-m2+crc+aes+sha3+fp16}"
TAG_CPU="${TAG_CPU:-m2}"

docker build . -t "josiah14/emacs:30.2-${TAG_CPU}-ubuntu-26.04-dev" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)" \
  --build-arg MCPU="${MCPU}"
