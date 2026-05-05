# Project Guide for Claude

This repo builds Docker images that package Doom Emacs as a preconfigured IDE for various languages. Each image is a full GUI-capable Emacs environment with a language-specific Doom configuration baked in. Images are personal — credentials are hardcoded in config and build scripts rather than templated.

## Reference guides

Four documents cover the Emacs/elisp domain:
- `GNU-EMACS-GUIDE.md` — Emacs concepts (buffers, modes, hooks, processes, display)
- `DOOM-EMACS-GUIDE.md` — Doom module system, config files, macros, package management
- `ELISP-STYLE-GUIDE.md` — naming, formatting, and idiom rules for elisp
- `ELISP-ARCHITECTURE-GUIDE.md` — architectural patterns for non-trivial elisp (generics, functional core, hooks, buffer-local state, error handling)

---

## Directory layout

```
{emacs-version}/{os}/{os-version}/{arch}/{ide-name}/
```

Examples:
```
29.2/ubuntu/22.04/x86_64/mercury-ide/
29.2/ubuntu/22.04/x86_64/python-ide/
30.2/ubuntu/24.04/x86_64/mercury-ide/
30.2/ubuntu/24.04/x86_64/dev/          ← build-base image (compiles Emacs from source)
```

When `arch` is absent (older images), `x86_64` is implied:
```
28.1/ubuntu/22.04/python-ide/          ← implicit x86_64
```

Each IDE directory contains:

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the IDE image on top of the dev image |
| `init.el` | Doom module selection (`doom!` block) |
| `config.el` | Personal Doom config (keybindings, theme, mode hooks) |
| `packages.el` | Extra package declarations beyond what enabled modules install |
| `build.sh` | Convenience wrapper for `docker build` with the correct args |

Each `dev/` directory contains only `Dockerfile` (and sometimes `build.sh`).

---

## Two-image build chain

Every Emacs version/OS combination has a **dev image** that compiles Emacs from source. IDE images use the dev image as a multi-stage build source:

```dockerfile
FROM josiah14/emacs:30.2-skylake-ubuntu-24.04-dev AS emacs-build
FROM ubuntu:24.04
...
COPY --from=emacs-build /usr/local /usr/local
```

Build the dev image first from its directory, then build the IDE image.

### Dev image

- Installs build dependencies, clones Emacs source, compiles with `--with-native-compilation --with-tree-sitter`, runs `make install`
- Registers GPG keys for the Emacs package archive
- Creates the runtime user matching the host UID/GID
- Tag format: `josiah14/emacs:{version}-{cpu-tune}-{os}-{os-version}-dev`
  - Example: `josiah14/emacs:30.2-skylake-ubuntu-24.04-dev`

### IDE image

- Copies the compiled Emacs binary from the dev image
- Installs runtime apt dependencies (fonts, audio libs, GTK, etc.)
- Creates the runtime user
- Clones Doom Emacs at a pinned commit, runs `doom install --aot --fonts` and `doom sync --aot`
- Copies in `config.el`, `init.el`, `packages.el` and runs `doom sync` again to apply them
- Tag format: `josiah14/{lang}-doom-emacs-ide:{version}-{cpu-tune}-{os}-{os-version}`
  - Example: `josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04`

---

## Dockerfile conventions

### Build args

Newer images (30.2+ dev, and in progress for 30.2 IDEs) use uppercase ARG names:

```dockerfile
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG FULLNAME
ARG EMAIL
```

Older images (≤ 29.2 IDEs) use lowercase:

```dockerfile
ARG username
ARG uid
ARG fullname
ARG email
```

The ARG name case must match how the variable is used in `RUN` commands. The dev Dockerfiles use uppercase consistently. IDE Dockerfiles for 29.2 and earlier use lowercase consistently. The 30.2 IDE Dockerfiles are being migrated to uppercase — check for case mismatches when editing them.

### Layer order rationale

Config files (`config.el`, `init.el`, `packages.el`) are `COPY`ed **after** the expensive `doom install` + `doom sync` steps. This means changing config without changing the module list (`init.el`) or package list (`packages.el`) only invalidates the last two layers:

```dockerfile
# Expensive — clone Doom, install fonts, first sync (cached unless Doom commit changes)
RUN git clone https://github.com/hlissner/doom-emacs ... \
    && doom install -! --aot --fonts \
    && doom sync -! -u -j ... --aot --gc

# Cheap to change
COPY --chown=... config.el /home/$username/.config/doom/config.el
COPY --chown=... init.el   /home/$username/.config/doom/init.el
COPY --chown=... packages.el /home/$username/.config/doom/packages.el

# Second sync applies the actual config (cached unless copied files change)
RUN doom sync -! -u -j ... --aot --gc
```

### Placeholder substitution

The Dockerfile contains a `sed` step to substitute `<full-name>` and `<email-address>` into `config.el`. In this personal repo, `config.el` files have real values hardcoded rather than placeholders, so the `sed` commands are effectively no-ops. The mechanism exists for templating.

### `ulimit -n 262144`

Doom's package install opens many files simultaneously. `ulimit -n 262144` and `--ulimit nofile=262144:262144` in `build.sh` prevent file descriptor exhaustion during `doom sync`.

---

## build.sh

Each `build.sh` is a thin `docker build` wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail

docker build . \
  --ulimit nofile=262144:262144 \
  -t josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04 \
  --build-arg USERNAME="${USER}" \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --build-arg FULL_NAME="<full-name>" \
  --build-arg EMAIL="<email-address>"
```

The tag and build args encode the target platform. Always run from the IDE's own directory (where the Dockerfile lives).

---

## Language-specific notes

### Mercury IDE

- No LSP server exists for Mercury with reliable support. Do not configure `lsp-mode` to activate in `mercury-mode`.
- Use `flycheck` with `mmc` (the Mercury compiler) as the checker.
- Mercury is compiled to native code via `mmc`; "grades" are compiler configuration strings that select GC strategy, parallelism, threading model, and backend. A typical grade: `asm_fast.gc.par.stseg`. Grade strings appear as build args and in flycheck configuration.
- The `mercury-ide` images install the Mercury compiler and standard library at image build time; the exact installation approach varies by image version.

### Python IDE

Uses LSP (pyright or pylsp), pyenv, and poetry depending on the `init.el` module flags.

### Haskell IDE

Uses LSP (HLS). See `29.2/ubuntu/22.04/x86_64/haskell-ide/`.

### Scala IDEs

Uses LSP Metals + Bloop. The `47deg-scala-ide` variant is a Scala IDE with 47 Degrees tooling. Both are in older (28.1) images only.

---

## Adding a new IDE image

1. Create `{version}/{os}/{os-version}/{arch}/{ide-name}/`
2. Copy the `Dockerfile`, `config.el`, `init.el`, `packages.el`, `build.sh` from the nearest equivalent IDE as a starting point
3. Update `init.el` to enable the appropriate `:lang` modules
4. Update `packages.el` to add language-specific packages not covered by modules
5. Update `config.el` for any language-specific keybindings or hooks
6. Update `Dockerfile` with any additional apt dependencies the language toolchain needs
7. Update `build.sh` with the correct image tag

When adding a new Emacs version, create the `dev/` directory first and build/push the dev image before working on IDE images that depend on it.
