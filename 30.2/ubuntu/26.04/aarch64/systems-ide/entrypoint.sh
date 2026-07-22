#!/bin/sh
set -e

# MOUNT_HOST_GUIX=1 (run.sh's default) bind-mounts the host's real
# /var/guix in at this exact path, which means the host's own guix-daemon
# is already running and its socket is already sitting at
# /var/guix/daemon-socket/socket the moment this container starts --
# starting a second daemon here would be redundant (same bind-mounted
# store) and would race the host daemon for the same socket path. Detected
# by the socket's own presence rather than reading MOUNT_HOST_GUIX
# directly -- this script never receives run.sh's environment, only the
# mounts it set up. Confirmed live: a bare `docker run -v /gnu:/gnu:ro -v
# /var/guix:/var/guix ... guix install` reaches the host daemon with zero
# extra config, since guix looks for the socket at this same default path.
if [ -S /var/guix/daemon-socket/socket ]; then
  echo "guix-daemon: bridged host daemon detected at /var/guix/daemon-socket/socket, skipping in-container daemon + key authorization" >&2
else
  # Starts guix-daemon in the background before handing off to the real
  # command (Emacs). Runs at container *runtime*, not at Docker build time --
  # sidesteps the "can't fork a persisting daemon during a RUN layer"
  # build-time restriction entirely, since a live container is a normal
  # process tree. This is the self-contained fallback path (MOUNT_HOST_GUIX=0,
  # or no host /gnu at all) -- no external daemon, no host dependency,
  # matching Nix's MOUNT_HOST_NIX=0 resilience property instead of the
  # Docker/Podman client-bridge pattern (see DECISIONLOG.md).
  # Absolute path, not a bare `guix-daemon` -- sudo resets PATH to its own
  # secure_path by default (confirmed live: /usr/local/sbin:/usr/local/bin:
  # /usr/sbin:/usr/bin:/sbin:/bin:/snap/bin, not the user's actual PATH),
  # which doesn't include ~/.local/bin, where guix-daemon is symlinked.
  sudo "$HOME/.local/bin/guix-daemon" --build-users-group=guixbuild >/tmp/guix-daemon.log 2>&1 &
  for _ in $(seq 1 30); do
    [ -S /var/guix/daemon-socket/socket ] && break
    sleep 0.5
  done

  # Without this, /etc/guix/acl has zero trusted keys (confirmed live) --
  # every `guix install` falls back to building entirely from source, which
  # is both slow and, at least once, hit a genuine build failure partway
  # through bootstrapping a full toolchain (gcc/glibc/etc.) from scratch.
  # The container is --rm (ephemeral), so this needs to run on every
  # launch, not just once -- same reasoning as the build-users-group setup
  # above. Confirmed live: `guix install hello` completes in seconds with
  # this in place, instead of needing a from-scratch compiler bootstrap.
  GUIX_PROFILE="$(readlink -f /var/guix/profiles/per-user/root/current-guix)"
  for host in ci.guix.gnu.org bordeaux.guix.gnu.org; do
    sudo "$GUIX_PROFILE/bin/guix" archive --authorize < "$GUIX_PROFILE/share/guix/$host.pub"
  done
fi

exec "$@"
