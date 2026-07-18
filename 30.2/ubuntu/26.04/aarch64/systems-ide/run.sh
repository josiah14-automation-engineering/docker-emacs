#!/usr/bin/env bash
set -euo pipefail

TAG_CPU="${TAG_CPU:-m2}"
USER="$(whoami)"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
IMAGE="josiah14/systems-doom-emacs-ide:30.2-${TAG_CPU}-ubuntu-26.04"

test_mode=0
flight_mounts=()
while getopts "tf:" opt; do
  case "$opt" in
    t)
      test_mode=1
      ;;
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
      echo "Usage: $0 [-t] [-f lang1,lang2,...]" >&2
      exit 1
      ;;
  esac
done

if [[ "$test_mode" == "1" ]]; then
  docker run --rm \
    -v "${SCRIPT_DIR}:/home/${USER}/work" \
    "${IMAGE}" \
    bats "/home/${USER}/work/smoketest.bats"
  exit $?
fi

# Read-only split for the shared Nix store, matching logic-ide/run.sh and
# host/logic-languages-ide (see logic-ide/BUILDLOG.md "2026-06-16"): /nix's
# contents are immutable from the container's perspective, but Nix still needs
# to write gc.lock/temproots under /nix/var/nix for any store operation,
# including a read-only `nix develop`. MOUNT_HOST_NIX=0 skips these and falls
# back to the nix-source-baked-in store if the host store is missing, corrupt,
# or mid-upgrade.
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

# Bridge the host's real Docker engine in rather than running a second
# dockerd (with its own separate image/container storage) inside this
# image -- docker.io here installs the CLIENT only. The socket is rootful
# (owned root:docker, group-rw), so the container's runtime user needs
# supplementary membership in a group matching that GID; `--group-add`
# resolves it at container-start time rather than baking a specific GID
# into the image, since it can differ per host. MOUNT_HOST_DOCKER=0 skips
# this (e.g. a host with no Docker installed at all).
docker_mounts=()
if [[ -S /var/run/docker.sock ]] && [[ "${MOUNT_HOST_DOCKER:-1}" == "1" ]]; then
  docker_mounts+=(
    -v /var/run/docker.sock:/var/run/docker.sock
    --group-add "$(stat -c '%g' /var/run/docker.sock)"
  )
else
  echo "warning: /var/run/docker.sock not found -- docker inside the IDE won't reach the host engine" >&2
fi

# Same idea for Podman, but rootless: the socket already lives under
# XDG_RUNTIME_DIR, which is bind-mounted unconditionally below, so no
# separate -v is needed here -- just point the podman CLIENT at it.
# Unlike Docker, podman has no client/server-only mode by default: with no
# CONTAINER_HOST set it manages LOCAL storage directly, which inside this
# image (no local podman storage set up on purpose) would silently create
# a redundant, broken local store instead of talking to the host. The
# socket requires the host to run `systemctl --user enable --now
# podman.socket` once (not on by default); MOUNT_HOST_PODMAN=0 skips this.
podman_env=()
if [[ -S "${XDG_RUNTIME_DIR}/podman/podman.sock" ]] && [[ "${MOUNT_HOST_PODMAN:-1}" == "1" ]]; then
  podman_env+=(-e "CONTAINER_HOST=unix://${XDG_RUNTIME_DIR}/podman/podman.sock")
else
  echo "warning: host podman.socket not active (systemctl --user enable --now podman.socket) -- podman inside the IDE won't reach the host engine" >&2
fi

# SSH agent forwarding so `nix develop`/direnv inside the container can
# authenticate git+ssh:// flake inputs using the host's agent and known_hosts.
#
# Mounted at the IDENTICAL host path (not remapped to a fixed /ssh-agent,
# unlike mercury-ide/logic-ide's own run.sh) -- this is the one bridge in
# this file that has to compose with a *nested* docker/podman invocation
# (e.g. running logic-ide's own run.sh from inside this container, via
# the docker/podman bridge above). A DooD `docker run` issued from inside
# this container is still executed by the HOST's real daemon (that's what
# the bridged socket means), which resolves bind-mount SOURCE paths
# against the HOST filesystem, not this container's. A fixed path like
# `/ssh-agent` is meaningless there -- the daemon would try to bind a
# host path that doesn't exist, which is exactly the "not a directory"
# OCI error this fixes (confirmed live: reproduced by tracing what
# `logic-ide/run.sh` actually sends the daemon when run from inside this
# container with the old remap in place). The real host path stays
# meaningful in both places, so it composes correctly with any further
# nesting.
ssh_mounts=()
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  ssh_mounts+=(
    -e SSH_AUTH_SOCK
    -v "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}"
  )
fi
if [[ -d "${HOME}/.ssh" ]]; then
  ssh_mounts+=(-v "${HOME}/.ssh:/home/${USER}/.ssh:ro")
fi

# Environment injection: this image's job is a reproducible, stable
# *tooling* environment, not a sandbox -- so a script tested inside the
# IDE via Emacs keybindings/M-x (sh-execute-region, compile,
# async-shell-command, ...) should see the same environment it would on
# the real host, not a re-derived approximation. Those are all
# non-interactive invocations, so mounting dotfiles wouldn't reach this at
# all (non-interactive shells don't source .bashrc/.zshrc even on the
# host itself) -- the actual fix is capturing this already-resolved
# environment (this shell already sourced its own dotfiles before running
# run.sh) and threading it straight into the container as -e flags,
# rather than trying to re-source the right dialect's rc file per
# execution context.
#
# Excluded: tool-resolution variables (PATH, LD_LIBRARY_PATH, MANPATH,
# PYTHONPATH) -- overriding these with host values would reintroduce
# exactly the version drift this image exists to prevent, trading script
# fidelity for breaking the container's own reproducibility. Also
# excluded: variables this script already sets explicitly by name
# elsewhere (SSH_AUTH_SOCK, XDG_RUNTIME_DIR, WAYLAND_DISPLAY, GDK_BACKEND,
# DISPLAY) -- a blanket pass-through would just duplicate those, not
# conflict (they're the same value either way), but there's no reason to
# set the same key twice; HOME/USER, already correct by construction (the
# container's own user mirrors the host username at build time); and
# shell-instance-mechanical variables that are either meaningless or
# actively wrong carried into a different process/directory (PWD, OLDPWD,
# SHLVL, TERM, _).
#
# This does NOT cover aliases or shell functions -- neither is part of
# the process environment (bash can export functions via a special
# encoding; zsh has no equivalent), so they only exist if a real
# interactive shell actually sources the rc file -- a vterm concern, not
# this. INJECT_HOST_ENV=0 disables this entirely.
host_env=()
if [[ "${INJECT_HOST_ENV:-1}" == "1" ]]; then
  host_env_exclude='^(PATH|LD_LIBRARY_PATH|MANPATH|PYTHONPATH|SSH_AUTH_SOCK|XDG_RUNTIME_DIR|WAYLAND_DISPLAY|GDK_BACKEND|DISPLAY|HOME|USER|PWD|OLDPWD|SHLVL|TERM|_)$'
  while IFS= read -r -d '' entry; do
    key="${entry%%=*}"
    [[ "$key" =~ $host_env_exclude ]] && continue
    host_env+=(-e "$entry")
  done < <(env -0)
fi

exec docker run --rm \
  --ipc host \
  --name "doom-systems-ide-aarch64" \
  -e WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR \
  -e GDK_BACKEND=wayland \
  -v "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}" \
  -v "${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro" \
  -v "${HOME}/Development/personal:/home/${USER}/Development/personal" \
  "${nix_mounts[@]+"${nix_mounts[@]}"}" \
  "${docker_mounts[@]+"${docker_mounts[@]}"}" \
  "${podman_env[@]+"${podman_env[@]}"}" \
  "${ssh_mounts[@]+"${ssh_mounts[@]}"}" \
  "${host_env[@]+"${host_env[@]}"}" \
  "${flight_mounts[@]+"${flight_mounts[@]}"}" \
  -w "/home/${USER}/Development/personal" \
  "${IMAGE}" &
