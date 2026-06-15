#!/usr/bin/env bash
set -euo pipefail

MARCH="${MARCH:-skylake}"
USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

flight_mounts=()
while getopts "f:" opt; do
    case "$opt" in
        f)
            IFS=',' read -ra langs <<< "$OPTARG"
            for lang in "${langs[@]}"; do
                dir="${SCRIPT_DIR}/flight-tests/${lang}"
                if [ -d "$dir" ]; then
                    flight_mounts+=("-v" "${dir}:/home/${USER}/flight-tests/${lang}")
                else
                    echo "Warning: flight-tests/${lang} not found, skipping" >&2
                fi
            done
            ;;
        *)
            echo "Usage: $0 [-f lang1,lang2,...]" >&2
            exit 1
            ;;
    esac
done

docker run --rm \
  --ipc host \
  --name "doom-systems-ide" \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro" \
  -v "${HOME}/Development/personal:/home/${USER}/Development/personal" \
  -v /nix:/nix \
  -v "${HOME}/.local/state/nix:/home/${USER}/.local/state/nix" \
  -v "${HOME}/.config/nix:/home/${USER}/.config/nix" \
  -w "/home/${USER}/Development/personal" \
  "${flight_mounts[@]+"${flight_mounts[@]}"}" \
  "josiah14/systems-doom-emacs-ide:30.2-${MARCH}-ubuntu-24.04" &

