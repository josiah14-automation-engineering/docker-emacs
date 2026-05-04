#!/usr/bin/env bash
set -euo pipefail

docker build . \
  --ulimit nofile=262144:262144 \
  -t josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04 \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --build-arg FULLNAME="Josiah Berkebile" \
  --build-arg EMAIL="josiah.berkebile@protonmail.com"
