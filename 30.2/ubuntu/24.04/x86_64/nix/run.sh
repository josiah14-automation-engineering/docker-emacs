#!/usr/bin/env bash
set -euo pipefail

NIX_VERSION="${NIX_VERSION:-2.33.3}"
USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Interactive bash shell in the nix-source image. Mounts the script dir as the
# working directory so smoketest.md sample flakes can be exercised against the
# host filesystem if needed.
docker run --rm -it \
  --name "nix-source" \
  -v "${SCRIPT_DIR}:/home/${USER}/work" \
  -w "/home/${USER}/work" \
  "josiah14/nix:${NIX_VERSION}-ubuntu-24.04"
