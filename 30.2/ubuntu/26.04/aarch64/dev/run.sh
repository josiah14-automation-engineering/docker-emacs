#!/usr/bin/env bash
set -euo pipefail

TAG_CPU="${TAG_CPU:-m2}"

docker run --rm -it \
  --ipc host \
  --name "docker-emacs-dev-aarch64" \
  -e WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR \
  -e GDK_BACKEND=wayland \
  -v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}" \
  "josiah14/emacs:30.2-${TAG_CPU}-ubuntu-26.04-dev"
