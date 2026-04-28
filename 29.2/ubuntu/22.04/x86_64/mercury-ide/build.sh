#!/bin/bash

docker build . --ulimit nofile=262144:262144 -t josiah14/mercury-doom-emacs-ide:29.2-skylake-ubuntu-22.04 \
  --build-arg username="${USER}" \
  --build-arg uid="${UID}" \
  --build-arg guid="${GID}" \
  --build-arg fullname="Josiah Berkebile" \
  --build-arg email="josiah.berkebile@protonmail.com"
