#!/usr/bin/env bash
set -euo pipefail

TAG_CPU="${TAG_CPU:-m2}"
FULLNAME="${FULLNAME:?Set FULLNAME before building (e.g. FULLNAME='Your Name' ./build.sh)}"
EMAIL="${EMAIL:?Set EMAIL before building (e.g. EMAIL='you@example.com' ./build.sh)}"

docker build . \
  --ulimit nofile=262144:262144 \
  -t "josiah14/systems-doom-emacs-ide:30.2-${TAG_CPU}-ubuntu-26.04" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --build-arg FULLNAME="${FULLNAME}" \
  --build-arg EMAIL="${EMAIL}"
