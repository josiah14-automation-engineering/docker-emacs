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

nix_mounts=()
if [[ -d /nix ]] && [[ "${MOUNT_HOST_NIX:-1}" == "1" ]]; then
  nix_mounts+=(
    -v /nix:/nix:ro
    -v /nix/var/nix:/nix/var/nix
    -v /nix/var/nix/profiles:/nix/var/nix/profiles:ro
    -v "${HOME}/.config/nix:/home/${USER}/.config/nix:ro"
    -v "${HOME}/.local/state/nix:/home/${USER}/.local/state/nix:ro"
  )
fi

# Same idea as MOUNT_HOST_NIX above, but simpler: Guix's store is
# content-addressed, so the container's own build-time-baked guix/guile
# symlinks (pointing at specific /gnu/store hashes) keep resolving correctly
# even once the host's /gnu replaces the container's local one -- no
# ldd-based host-binary-bridging wrapper needed (this port never grew one
# for Nix either -- see the aarch64 port's run.sh for that case, which
# applies to a differently-packaged host Nix, not to Guix here). Confirmed
# live: `docker run -v /gnu:/gnu:ro -v /var/guix:/var/guix ... guix install`
# reached the host's daemon and completed immediately, no
# GUIX_DAEMON_SOCKET override required -- guix looks for the socket at this
# same default path. /var/guix is mounted read-write (not :ro) since it
# holds the daemon socket dir and per-user profile symlinks that get
# rewritten on every `guix install`/`upgrade`. entrypoint.sh detects this
# bridge itself (via the socket's presence) and skips starting its own
# in-container daemon when it's active. MOUNT_HOST_GUIX=0 falls back to
# that self-contained daemon if the host's Guix is missing, corrupt, or
# mid-upgrade.
guix_mounts=()
if [[ -d /gnu ]] && [[ "${MOUNT_HOST_GUIX:-1}" == "1" ]]; then
  guix_mounts+=(
    -v /gnu:/gnu:ro
    -v /var/guix:/var/guix
  )
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

# Same idea for Podman, but rootless: unlike the aarch64 port, this script
# has no unconditional XDG_RUNTIME_DIR bind mount (X11/DISPLAY here, not
# Wayland), so the socket itself is mounted explicitly rather than relying
# on a broader mount to already cover it. Podman has no client/server-only
# mode by default: with no CONTAINER_HOST set it manages LOCAL storage
# directly, which inside this image (no local podman storage set up on
# purpose) would silently create a redundant, broken local store instead
# of talking to the host. The socket requires the host to run `systemctl
# --user enable --now podman.socket` once (not on by default);
# MOUNT_HOST_PODMAN=0 skips this.
podman_mounts=()
podman_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
if [[ -S "${podman_sock}" ]] && [[ "${MOUNT_HOST_PODMAN:-1}" == "1" ]]; then
  podman_mounts+=(
    -v "${podman_sock}:${podman_sock}"
    -e "CONTAINER_HOST=unix://${podman_sock}"
  )
else
  echo "warning: host podman.socket not active (systemctl --user enable --now podman.socket) -- podman inside the IDE won't reach the host engine" >&2
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
# excluded: variables this script (or a sibling bridge below/above) sets
# explicitly by name (XDG_RUNTIME_DIR, WAYLAND_DISPLAY, GDK_BACKEND,
# DISPLAY) -- a blanket pass-through would just duplicate those, not
# conflict, but there's no reason to set the same key twice. SSH_AUTH_SOCK
# is excluded too even though this port has no ssh_mounts block of its own
# (unlike aarch64's run.sh) to actually bridge it -- SSH forwarding was
# never wired up on this port at all; excluding it here is a placeholder
# for parity with aarch64's exclusion list, not a claim that it's handled
# elsewhere in this file. HOME/USER are already correct by construction
# (the container's own user mirrors the host username at build time); and
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

docker run --rm \
  --ipc host \
  `# guix-daemon's own build sandbox needs all three of these -- each` \
  `# confirmed live in isolation, one at a time, each fix uncovering the` \
  `# next blocker further into an actual build. seccomp=unconfined: the` \
  `# sandbox calls personality() (disables ASLR for reproducible builds),` \
  `# blocked by Docker's default seccomp profile. --cap-add SYS_ADMIN: it` \
  `# also calls clone() to create its own nested namespaces per build,` \
  `# blocked independently of seccomp by Docker's default capability set.` \
  `# --cap-add NET_ADMIN: it also brings up a loopback interface inside` \
  `# that new network namespace, needing this capability separately from` \
  `# SYS_ADMIN. None of these are a new category of risk in this` \
  `# container: it already bridges docker.sock below, which alone is` \
  `# already host-root-equivalent trust (see DECISIONLOG.md) -- and the` \
  `# realistic alternative to containerizing this at all is running the` \
  `# same tooling directly on the host with the same docker-group` \
  `# privileges anyway.` \
  --security-opt seccomp=unconfined \
  --cap-add SYS_ADMIN \
  --cap-add NET_ADMIN \
  --name "doom-systems-ide" \
  -e DISPLAY="${DISPLAY}" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro" \
  -v "${HOME}/Development/personal:/home/${USER}/Development/personal" \
  "${nix_mounts[@]+"${nix_mounts[@]}"}" \
  "${guix_mounts[@]+"${guix_mounts[@]}"}" \
  "${docker_mounts[@]+"${docker_mounts[@]}"}" \
  "${podman_mounts[@]+"${podman_mounts[@]}"}" \
  "${host_env[@]+"${host_env[@]}"}" \
  -w "/home/${USER}/Development/personal" \
  "${flight_mounts[@]+"${flight_mounts[@]}"}" \
  "josiah14/systems-doom-emacs-ide:30.2-${MARCH}-ubuntu-24.04" &

