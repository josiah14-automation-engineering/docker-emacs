#!/bin/bash

docker build . -t josiah14/emacs:29.2-skylake-ubuntu-24.04-dev \
  --build-arg USERNAME="${USER}" \
  --build-arg UID="${UID}" --build-arg GID="${GID}"
