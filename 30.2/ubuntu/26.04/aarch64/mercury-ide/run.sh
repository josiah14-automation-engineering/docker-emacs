#!/usr/bin/env bash
set -euo pipefail

TAG_CPU="${TAG_CPU:-m2}"
USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
IMAGE="josiah14/mercury-doom-emacs-ide:30.2-${TAG_CPU}-ubuntu-26.04"

if [[ "${1:-}" == "--test" || "${1:-}" == "-t" ]]; then
  docker run --rm \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    "${IMAGE}" \
    bats "/home/${USER}/work/smoketest.bats"
  exit $?
fi

# Read-only split for the shared Nix store, matching systems-ide/run.sh and
# host/logic-languages-ide (see BUILDLOG.md "2026-06-16"): /nix's contents are
# immutable from the container's perspective, but Nix still needs to write
# gc.lock/temproots under /nix/var/nix for any store operation, including a
# read-only `nix develop`. MOUNT_HOST_NIX=0 skips these and falls back to the
# nix-source-baked-in store if the host store is missing, corrupt, or mid-upgrade.
nix_mounts=()
if [[ -d /nix ]] && [[ "${MOUNT_HOST_NIX:-1}" == "1" ]]; then
  nix_mounts+=(
    -v /nix:/nix:ro
    -v /nix/var/nix:/nix/var/nix
    -v /nix/var/nix/profiles:/nix/var/nix/profiles:ro
    -v "${HOME}/.config/nix:/home/${USER}/.config/nix:ro"
    -v "${HOME}/.local/state/nix:/home/${USER}/.local/state/nix:ro"
  )

  # This host's Nix comes from Fedora's nix-core RPM, not the traditional
  # installer script: `nix` itself lives at /usr/bin/nix (dynamically linked
  # against /lib64/libnix*.so.* + friends), entirely outside /nix. The
  # bind mounts above only cover /nix and the user's profile state (which on
  # this host holds just the *extra* tools -- nil/direnv/bats/nixfmt --
  # installed on top), so they never actually expose a working `nix`
  # executable. Confirmed empirically: bind-mounting /usr/bin/nix plus its
  # ldd-discovered deps (not hardcoded -- these are version-suffixed .so
  # filenames that shift on every nix-core update) works fine paired with
  # the host /nix state above, including network-dependent flake fetches.
  # ldd deps are re-resolved every launch rather than cached, since the
  # host's nix-core package can update between runs.
  #
  # LD_LIBRARY_PATH=/lib64 is required for these libs to be found at all --
  # Ubuntu's ld.so.conf.d never searches /lib64 (that's a Fedora/RHEL
  # convention) -- but it's deliberately NOT set container-wide. Several of
  # nix's deps (libssl, libcrypto, libcurl, libz, liblzma, libzstd, ...) are
  # common library names other apt-installed tools in this image (git,
  # gnupg, curl, imagemagick) also load; a blanket LD_LIBRARY_PATH=/lib64
  # would risk those silently resolving to Fedora-built libs instead of
  # Ubuntu's own apt-installed ones. Scoped instead to a wrapper script that
  # only affects this one binary's invocation.
  if [[ -x /usr/bin/nix ]]; then
    host_nix_bridge_dir="${SCRIPT_DIR}/.host-nix-bridge"
    mkdir -p "${host_nix_bridge_dir}"
    cat > "${host_nix_bridge_dir}/nix" <<'WRAPPER'
#!/bin/sh
export LD_LIBRARY_PATH=/opt/host-nix/lib64
exec /opt/host-nix/bin/nix "$@"
WRAPPER
    chmod +x "${host_nix_bridge_dir}/nix"

    nix_mounts+=(-v "/usr/bin/nix:/opt/host-nix/bin/nix:ro")
    while IFS= read -r lib; do
      nix_mounts+=(-v "${lib}:/opt/host-nix/lib64/$(basename "${lib}"):ro")
    done < <(ldd /usr/bin/nix | awk '{print $3}' | grep '^/')
    nix_mounts+=(-v "${host_nix_bridge_dir}/nix:/usr/local/bin/nix:ro")
  fi
fi

# SSH agent forwarding so `nix develop`/direnv inside the container can
# authenticate git+ssh:// flake inputs using the host's agent and known_hosts.
ssh_mounts=()
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  ssh_mounts+=(
    -e SSH_AUTH_SOCK=/ssh-agent
    -v "${SSH_AUTH_SOCK}:/ssh-agent"
  )
fi
if [[ -d "${HOME}/.ssh" ]]; then
  ssh_mounts+=(-v "${HOME}/.ssh:/home/${USER}/.ssh:ro")
fi

exec docker run --rm \
  --ipc host \
  --name "doom-mercury-ide-aarch64" \
  -e WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR \
  -e GDK_BACKEND=wayland \
  -v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}" \
  -v "${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro" \
  -v "${HOME}/Development/personal:/home/${USER}/Development/personal" \
  "${nix_mounts[@]+"${nix_mounts[@]}"}" \
  "${ssh_mounts[@]+"${ssh_mounts[@]}"}" \
  -w "/home/${USER}/Development/personal" \
  "${IMAGE}" &

