#!/usr/bin/env bash
set -euo pipefail
 
MARCH="${MARCH:-skylake}"
USER="$(whoami)"

docker run --rm \
  --ipc host \
  --name "doom-systems-ide" \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro" \
  -v "${HOME}/Development/personal:/home/${USER}/Development/personal" \
  -w "/home/${USER}/Development/personal" \
  "josiah14/systems-doom-emacs-ide:30.2-${MARCH}-ubuntu-24.04" &

