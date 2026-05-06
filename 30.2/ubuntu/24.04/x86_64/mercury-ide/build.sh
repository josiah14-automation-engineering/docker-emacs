#!/usr/bin/env bash
set -euo pipefail

MARCH="${MARCH:-skylake}"
MTUNE="${MTUNE:-skylake}"
FULLNAME="${FULLNAME:?Set FULLNAME before building (e.g. FULLNAME='Your Name' ./build.sh)}"
EMAIL="${EMAIL:?Set EMAIL before building (e.g. EMAIL='you@example.com' ./build.sh)}"

docker build . \
  --ulimit nofile=262144:262144 \
  -t "josiah14/mercury-doom-emacs-ide:30.2-${MARCH}-ubuntu-24.04" \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --build-arg FULLNAME="${FULLNAME}" \
  --build-arg EMAIL="${EMAIL}" \
  --build-arg MARCH="${MARCH}" \
  --build-arg MTUNE="${MTUNE}"
