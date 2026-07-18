# docker-emacs

Personal Doom Emacs IDE images for multiple languages, built on Docker. Each image is a fully compiled Emacs with a language-specific Doom configuration baked in — ready to run as a GUI or console IDE.

## Images

Each Emacs version/OS combination has a **dev** image (compiles Emacs from source) and one or more **IDE** images built on top of it.

| Emacs | OS | Arch | IDE | Image tag |
|---|---|---|---|---|
| 30.2 | Ubuntu 24.04 | x86_64 | dev | `josiah14/emacs:30.2-skylake-ubuntu-24.04-dev` |
| 30.2 | Ubuntu 24.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04` |
| 29.2 | Ubuntu 24.04 | x86_64 | dev | `josiah14/emacs:29.2-skylake-ubuntu-24.04-dev` |
| 29.2 | Ubuntu 24.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:29.2-skylake-ubuntu-24.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | dev | `josiah14/emacs:29.2-skylake-ubuntu-22.04-dev` |
| 29.2 | Ubuntu 22.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | Haskell | `josiah14/haskell-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | aarch64 | dev | `josiah14/emacs:29.2-ubuntu-22.04-aarch64-dev` |
| 29.2 | Alpine 3.20.2 | aarch64 | dev | `josiah14/emacs:29.2-alpine-3.20.2-aarch64-dev` |
| 28.1 | Ubuntu 22.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 22.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 22.04 | x86_64 | 47deg Scala | `josiah14/47deg-scala-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:28.1-ubuntu-20.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:28.1-ubuntu-20.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | 47deg Scala | `josiah14/47deg-scala-doom-emacs-ide:28.1-ubuntu-20.04` |
| 27.2 | Ubuntu 20.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:27.2-ubuntu-20.04` |
| 27.2 | Ubuntu 20.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:27.2-ubuntu-20.04` |

## Building

Each IDE directory contains a `build.sh` that runs `docker build` with the correct args. To build the 30.2 Mercury IDE:

```bash
cd 30.2/ubuntu/24.04/x86_64/dev
./build.sh            # build the dev image first

cd ../mercury-ide
./build.sh            # build the IDE image
```

If a `build.sh` is absent (older images), build manually from the IDE directory:

```bash
docker build \
  --ulimit nofile=262144:262144 \
  --build-arg username=$USER \
  --build-arg uid=$UID \
  --build-arg fullname="Your Name" \
  --build-arg email="you@example.com" \
  -t josiah14/python-doom-emacs-ide:28.1-ubuntu-22.04 \
  .
```

Builds take a while — Emacs compiles from source in the dev image, and `doom sync` runs with AOT compilation in the IDE image.

## Running

### Console

```bash
docker run -it --rm josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04
```

### GUI

```bash
docker run -it --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /path/to/your/project:/path/to/your/project \
  josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04
```

## On first boot

Due to limitations in Doom Emacs, a couple of steps can't be automated through the Dockerfile and need to be done manually after the first run.

1. First boot will perform font and unicode mapping. Wait for it to complete before doing anything else.
1. That first pass isn't enough to cache the unicode mapping permanently. Find the running container name with `docker ps`, then run `docker exec -it <container-name> bash`. From inside the container, run `emacs` a second time and wait for the unicode mapping to finish again.
1. Install the icon fonts Doom needs but can't bundle automatically. Inside Emacs, run `M-x all-the-icons-install-fonts` (in Doom, `M-x` is `SPC :`).
1. Commit the container to a new image so you don't repeat these steps:
   ```bash
   docker commit <container-name> <your-image-name>:ready
   ```
1. From here on, boot from the committed image — fonts and unicode will be cached and icons will be present.

If icons are still missing after these steps, repeat them once more.

## Nix flake environments

Some IDE images (mercury-ide and systems-ide, both 30.2/ubuntu/24.04/x86_64) bundle a
Nix install — `nix`, `direnv`, `nix-direnv`, `nil`, `bats` on `~/.nix-profile/bin` —
plus Doom's `:tools direnv` and `(nix +lsp)` + `:tools lsp` modules. This lets any
project pin its own toolchain via `flake.nix`, independent of whatever the image happens
to have baked in. The setup is general — any future IDE that wires in the same
`nix-source` stage gets this for free.

### Per-project setup

Add an `.envrc` to the project containing:

```
use flake
```

This requires the project's `flake.nix` to expose `devShells.${system}.default` (or
add an explicit attribute path, e.g. `use flake .#mercury`).

### How it works

1. `:tools direnv` (`envrc.el`) is active globally via `envrc-global-mode`.
2. Opening any file under a directory with `.envrc` triggers direnv, via nix-direnv's
   caching `direnvrc` (already wired into `~/.config/direnv/`).
3. `use flake` resolves the flake's devShell, and `envrc.el` overlays its environment
   buffer-locally — `exec-path`/`process-environment` for that project's buffers now
   point at the devShell's tools first.
4. Language tooling that resolves bare command names via `executable-find` (e.g.
   flycheck-mercury's `mercury-mmc` checker, which invokes plain `"mmc"`) picks up the
   project's pinned version automatically instead of the image's baked-in one.
5. `(nix +lsp)` + `:tools lsp` give `nil` (the Nix LSP server) for editing `flake.nix`
   itself — independent of any project's devShell, since `nil` comes from the image's
   own `~/.nix-profile/bin`.

### First-time activation

direnv refuses to evaluate an `.envrc` until it's explicitly trusted. In Emacs, run
`M-x envrc-allow` (equivalent to `direnv allow`) the first time you open a file in a
project with a new or changed `.envrc`.

### Known limitations

The container runs with `--rm`. When the host has Nix installed, `/nix`, `~/.local/state/nix`, and `~/.config/nix` are bind-mounted from the host (see "Shared Nix store" below), but the rest of `$HOME` is not, so:

- **`direnv allow` doesn't persist across container restarts.** The allow-list lives
  under `$HOME/.local/share/direnv/`, which isn't bind-mounted, so expect to re-run
  `M-x envrc-allow` each fresh container session. If this becomes too painful, the fix
  is bind-mounting `~/.local/share/direnv` from the host as well.

### Shared Nix store

When the host has a `/nix` directory, mercury-ide (`host/logic-languages-ide`) and
systems-ide (`run.sh`) automatically bind-mount five paths using a read/write split:

| Path | Mode |
|---|---|
| `/nix` | read-only |
| `/nix/var/nix` | read-write (Nix needs `gc.lock` and `temproots` for any store operation, including `nix develop`) |
| `/nix/var/nix/profiles` | read-only (re-pinned; `nix develop` writes to `gcroots/auto`, never profiles) |
| `~/.local/state/nix` | read-only |
| `~/.config/nix` | read-only |

The container's `/nix/store`, `nix.conf`, and `~/.nix-profile` are therefore the
host's, live — not the copies the `nix-source` stage baked in at build time. Those
baked-in copies remain in the image as a fallback: if the host has no `/nix`, or you
set `MOUNT_HOST_NIX=0`, the container runs entirely on its own internal store.

The store is kept read-only to protect against inconsistency if the container runs a
different libc or kernel ABI from the host. All store writes go through the host.

Consequences:

- **The first `nix develop` per session is no longer slow.** Anything already built on
  the host — including from-source builds of `overrideAttrs`'d packages not present in
  any binary cache — is already in the shared `/nix/store`.
- **Host and container Nix versions must match.** `/nix/var/nix/db` is a SQLite
  database with a version-specific schema; a container running a different Nix version
  than whatever last wrote that DB risks corrupting or being unable to read it. Both
  `mercury-ide/Dockerfile` and `systems-ide/Dockerfile` pin their `nix-source` stage to
  `josiah14/nix:2.34.7-ubuntu-24.04`, matching the host's Nix 2.34.7. `nix/Dockerfile`'s
  `ARG NIX_VERSION` is the single source of truth for that image's version —
  `nix/build.sh`/`nix/run.sh` derive it via `grep` rather than duplicating it. If an IDE
  needs to stay on an older Nix, pin an older `nix-source` tag and keep that IDE's own
  `/nix` store inside the container (no host bind mount) until it's ready to move.
- **The host's `nix.conf` and profile are now canonical.** They need `pipe-operators`
  in `experimental-features`, and `nil`, `direnv`, `nix-direnv`, `bats` installed via
  `nix profile install` (not `nix-env` — `nix-env` can't read `nix profile install`'s
  manifest format).
- **`MOUNT_HOST_NIX=0` skips all host nix mounts.** Use this if the host `/nix`
  directory exists but the store is corrupt or mid-upgrade. The container falls back to
  the baked-in `nix-source` store without needing to move or remove `/nix` on the host.

Verify the shared store from inside either container with `bats nix-smoketest.bats`.

### Wiring a new IDE for this

1. Add the `nix-source` stage, the `COPY --from=nix-source` block, and the
   `~/.nix-profile` symlink recreation to the Dockerfile (see mercury-ide's
   `Dockerfile` for the pattern, including why the symlink has to be recreated). Pin
   `nix-source` to the same Nix version as the host (`nix/Dockerfile`'s
   `ARG NIX_VERSION`).
2. Add `:tools direnv` and `(nix +lsp)` plus a bare `:tools lsp` to `init.el`.
3. Copy/adapt `nix-keybindings.el` and load it from `config.el`.
4. For projects with `git+ssh://` flake inputs, forward the SSH agent and `~/.ssh`
   in the `host/*` run script (see mercury-ide's `host/logic-languages-ide`).
5. In the `host/*`/`run.sh` launcher, add the conditional nix mount block (see
   mercury-ide's `host/logic-languages-ide` or systems-ide's `run.sh` for the pattern):
   guard with `[[ -d /nix ]] && [[ "${MOUNT_HOST_NIX:-1}" == "1" ]]` and populate a
   `nix_mounts` array with the five-path RO/RW split described in "Shared Nix store"
   above. Copy/adapt `nix-smoketest.bats` to verify the wiring.

## Docker and Podman

systems-ide (30.2, both aarch64 and x86_64) installs the `docker` and `podman`
**clients** only — neither engine's daemon or image/container storage runs inside the
image. `run.sh` bridges each client to the corresponding engine already running on the
host, the same "share the host's state instead of duplicating it" idea as the Nix
store above, for the same reason: container image/volume storage is often many GB, and
running a second engine inside the IDE would mean a second copy of that storage rather
than one shared copy.

### Docker

Rootful, single system-wide `docker.service`, socket at the fixed path
`/var/run/docker.sock`, owned `root:docker` with group-rw permissions. `run.sh`
bind-mounts it at the identical path (the Docker CLI's own default lookup, so no
`DOCKER_HOST` is needed) and adds `--group-add "$(stat -c '%g' /var/run/docker.sock)"`
so the container's runtime user can reach it without root — resolved at
container-start time rather than baked into the image, since the GID can differ per
host. `MOUNT_HOST_DOCKER=0` skips this.

### Podman

Rootless, per-user `podman.socket` (a systemd **user** unit — not enabled by default
even if `podman` itself is installed; run `systemctl --user enable --now
podman.socket` once). Socket lives at `$XDG_RUNTIME_DIR/podman/podman.sock`, owned
directly by the invoking user, no group trick needed.

**Podman's remote mode is not optional the way it might look.** Unlike the Docker CLI
(always a thin client, no other mode exists), the `podman` CLI defaults to managing
*local* storage directly whenever no `CONTAINER_HOST`/`--remote` is set. With no local
podman storage configured in the image on purpose, an unset `CONTAINER_HOST` doesn't
fail loudly — it silently starts building a redundant, broken local store inside the
container instead of ever reaching the host. `run.sh` always sets `CONTAINER_HOST`
explicitly for this reason. `MOUNT_HOST_PODMAN=0` skips the whole bridge.

### Using both from inside Emacs

`:tools docker` (Doom's `docker.el`) is already enabled — `SPC o D` opens its tabulated
container/image/volume UI, and `dockerfile-mode` already matches `Containerfile` as
well as `Dockerfile`. `docker.el` only targets one binary at a time via the
`docker-command` variable (default `"docker"`); `docker-keybindings.el` adds `SPC o c`
to toggle it to `"podman"` and back, since there's no built-in way to view both
through the same UI simultaneously.

### Known limitations

- **Podman needs a one-time host prerequisite** (`systemctl --user enable --now
  podman.socket`) that isn't part of any package install — `run.sh` prints a warning
  if the socket isn't found rather than failing silently.
- **Whichever engine builds an image is the only one that can see it.** Docker and
  Podman use separate storage backends by default; an image built with `docker build`
  won't show up under `podman images` even with both bridged, and vice versa. This
  isn't a bug in the bridge — it's the same as running both engines side-by-side on
  the host directly.
- **No isolation between the IDE and the host's real containers, on purpose.** `docker
  rm`/`podman rmi` run from inside the IDE affect the same containers/images visible
  from a host terminal. The point of this bridge is exactly that — a traditional IDE
  doesn't sandbox you from your own machine either.

### Wiring a new IDE for this

1. Add `docker.io` and/or `podman` to the Dockerfile's apt list (client only — no
   `dockerd`/podman-storage setup needed).
2. `:tools docker` in `init.el` if not already enabled; no flags needed for this.
3. In `run.sh`, add the conditional `docker_mounts`/`podman_env` (or `podman_mounts`,
   if the port has no unconditional `XDG_RUNTIME_DIR` mount already — see systems-ide's
   two `run.sh`s for both shapes) blocks, guarded by `MOUNT_HOST_DOCKER`/
   `MOUNT_HOST_PODMAN` matching the pattern above.
4. Copy `docker-keybindings.el` and its `load!` line if the engine-toggle convenience
   is wanted.

## Environment injection

`run.sh` also captures the invoking shell's environment and threads it into the
container, so a script exercised through Emacs keybindings/`M-x`
(`sh-execute-region`, `compile`, `async-shell-command`, ...) behaves the way it would
on the real host rather than a re-derived approximation. This container's job is a
reproducible, stable *tooling* environment, not a sandbox, so a script that silently
behaves differently inside the IDE than it would on the host defeats the point of
testing it there.

Mechanically: `env -0` (NUL-separated, safe against embedded newlines) from the shell
that runs `run.sh` — already fully dotfile-sourced, since `run.sh` always runs inside
an interactive host shell — piped through a regex exclusion filter, and the survivors
passed through as `-e KEY=value`. `INJECT_HOST_ENV=0` disables it entirely.

**The exclusion list is the important part, not the capture.** Blind wholesale
injection would work against the container's own purpose: `PATH`, `LD_LIBRARY_PATH`,
`MANPATH`, and `PYTHONPATH` describe *how to find binaries*, and overriding them with
the host's own values would reintroduce exactly the version drift this image exists to
prevent. Also excluded: variables `run.sh` already bridges deliberately to a
**different** value than the raw host one (`SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`,
`WAYLAND_DISPLAY`, `GDK_BACKEND`, `DISPLAY`), `HOME`/`USER` (already correct by
construction — the container's own user is built at image-build time to mirror the
host username), and shell-instance-mechanical variables that are either meaningless or
actively wrong carried into a different process/directory (`PWD`, `OLDPWD`, `SHLVL`,
`TERM`, `_`).

### Known limitations

- **This covers variables only — not aliases or shell functions.** Neither is part of
  the process environment (bash can export functions via a special encoding; zsh has
  no equivalent), so neither survives this mechanism regardless of what's injected.
  They only exist if a real interactive shell actually sources an rc file — relevant
  to opening a real shell in `vterm`, not to `M-x`/keybinding-driven execution. If your
  own bash/zsh/nu function library matters inside the IDE, the intended path is
  packaging it as its own git-pullable dependency and cloning it in, not baking
  dotfiles into image config.
- **Values are captured once, at container launch**, not live — changing an
  environment variable in your host shell after the container is already running has
  no effect on it.

### Wiring a new IDE for this

Add the `host_env` capture block to the `host/*`/`run.sh` launcher (see systems-ide's
two `run.sh`s), keeping the exclusion list in sync with whatever that image's own
Dockerfile deliberately bridges to a different value (so the blind capture never races
a specific remapping) plus the standard tool-resolution variables above.

## Alternatives

- [flycheck/emacs-cask](https://hub.docker.com/r/flycheck/emacs-cask): minimal Emacs compiled from source with Cask
- [jgkamat/airy-docker-emacs](https://github.com/jgkamat/airy-docker-emacs): Alpine-based images with Emacs from the package manager
- [JAremko/docker-emacs](https://github.com/JAremko/docker-emacs): Docker images focused on GUI usage
- [rejeep/evm](https://github.com/rejeep/evm): pre-built Emacs binaries
