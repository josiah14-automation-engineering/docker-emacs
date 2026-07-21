ARG MARCH=skylake
ARG MTUNE=skylake

FROM josiah14/emacs:30.2-${MARCH}-ubuntu-24.04-dev AS emacs-build

FROM ubuntu:24.04 AS go-build
ARG GO_VERSION=1.26.3
ARG GO_SHA256=2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556
RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz \
    && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

FROM josiah14/nix:2.34.7-ubuntu-24.04 AS nix-source

# --- Final image ---
FROM ubuntu:24.04

ARG MARCH
ARG MTUNE
ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG FULLNAME
ARG EMAIL
ARG DOOM_REPO=https://github.com/doomemacs/doomemacs
ARG DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57
ARG POWERLINE_FONTS_COMMIT=a029626780dd4af32f15a3e708a5b00528c22f1d
ARG NERD_ICONS_COMMIT=1db0b0b9203cf293b38ac278273efcfc3581a05f
ARG NFM_SHA256=f0f624d9b474bea1662cf7e862d44aebe1ae1f6c7f9cb7a0ca5d0e5ac9561c60
ARG ZSHDB_VERSION=1.1.4
ARG NU_VERSION=0.114.1
ARG NU_SHA256=8802b26edcdf1a64477567b5ce909fbae3d72d731c8f0847892ea16c6fa73c53
ARG CMAKE_LANGUAGE_SERVER_VERSION=0.1.11
ARG CONAN_VERSION=2.30.0
ARG LUA_LANGUAGE_SERVER_VERSION=3.18.2
ARG LUA_LANGUAGE_SERVER_SHA256=273af33f26f4a1143f27c96d9f9e1188aba619c71e0807042134f66b4bd27f24
ARG STYLUA_VERSION=2.5.2
ARG STYLUA_SHA256=0ef2ebf0b7e5a652b65c4cb96c6d9ffb3981a98547de3c764465bbf54a8d761a
ARG VCPKG_VERSION=2026.06.24
ARG NUPM_COMMIT=9a28419bf91aadc58999d83e0f6ef8d9dbfa7d9f
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
# typescript-language-server internally needs to `require('typescript')`
# to get at tsserver -- Node's own module resolution only checks a
# project-local node_modules by default, not npm's global install
# location, so a globally npm-installed `typescript` (this project's
# whole point, for a lone script with no package.json) is otherwise
# invisible to it. Confirmed directly against running ubuntu:26.04/24.04
# containers rather than assumed: `npm root -g` resolves to
# /usr/local/lib/node_modules on both.
ENV NODE_PATH=/usr/local/lib/node_modules
# typescript-language-server also needs the classic lib/tsserver.js that
# ships inside the `typescript` package -- TypeScript 7.0's native
# (Go-ported) rewrite dropped it entirely (package only exposes `tsc`
# now), so pinning the npm install below to the last release that still
# ships it (6.0.3) is required, not just NODE_PATH. Confirmed by
# inspecting both packages' contents directly in a running container --
# 7.0.2's lib/ has no tsserver*.js at all.
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:${PATH}"
ENV GOPATH=/home/${USERNAME}/go
ENV GOAMD64=v3
ENV GOTOOLCHAIN=auto
ENV PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"

COPY --from=emacs-build /usr/local /usr/local
COPY --from=go-build /usr/local/go /usr/local/go

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean

RUN apt-get update -y && \
    apt-get install -y \
      `# --- system utilities ---` \
      bash \
      bzip2 \
      ca-certificates \
      coreutils \
      curl \
      findutils \
      gawk \
      git \
      gnupg \
      locales \
      sudo \
      tar \
      texinfo \
      unzip \
      wget \
      xz-utils \
      zip \
      `# --- cli live troubleshooting tools ---` \
      aspell \
      fd-find \
      iputils-ping \
      openssh-client \
      ripgrep \
      vim \
      `# --- native elisp compilation ---` \
      libgccjit-13-dev \
      `# --- tree-sitter grammar compilation (nushell-ts-mode) ---` \
      `# libgccjit-dev above only provides the JIT library Emacs links against` \
      `# for native-comp -- it doesn't put a cc/gcc executable on PATH. Tree-` \
      `# sitter grammars are compiled independently at build time via a real` \
      `# compiler invocation, not linked against libgccjit at all.` \
      gcc \
      `# --- emacs runtime: audio ---` \
      alsa-base \
      libasound2t64 \
      libcanberra-gtk3-0 \
      `# --- emacs runtime: display ---` \
      dbus \
      dbus-x11 \
      gpm \
      libglib2.0-0t64 \
      libgpm2 \
      libgtk-3-0 \
      libsm6 \
      libxaw7 \
      libxcb-util1 \
      libxext6 \
      libxrender1 \
      x11-utils \
      `# --- emacs runtime: image ---` \
      imagemagick \
      libgif7 \
      libjpeg-turbo8 \
      liblcms2-2 \
      librsvg2-2 \
      libtiff6 \
      libwebp7 \
      libwebpdecoder3 \
      libwebpdemux2 \
      `# --- emacs runtime: text / encoding ---` \
      libm17n-0 \
      libncurses6 \
      libncursesw6 \
      libtinfo6 \
      `# --- emacs runtime: misc ---` \
      libacl1 \
      libgnutls30 \
      libjansson4 \
      liblockfile-bin \
      libtree-sitter0 \
      libxml2 \
      zlib1g \
      `# --- shell ide ---` \
      autoconf \
      automake \
      bats \
      make \
      nodejs \
      npm \
      shellcheck \
      zsh \
      `# --- c/c++/cmake ide ---` \
      `# ccls deliberately excluded: no apt package, no prebuilt release` \
      `# binaries -- building it from source against a matching libclang` \
      `# would be real added fragility for a server Doom's own :lang cc` \
      `# module already deprioritizes below clangd. gcc is installed` \
      `# earlier above already, for tree-sitter grammar compilation.` \
      clang \
      clangd \
      clang-format \
      cmake \
      g++ \
      gdb \
      ninja-build \
      `# pipx here rather than its own group -- only pulled in for` \
      `# cmake-language-server and conan, both installed just below.` \
      pipx \
      `# --- container engines: docker/podman CLIENTS only ---` \
      `# No dockerd/podman storage runs in this image -- both engines and` \
      `# all image/container storage live on the HOST; run.sh bridges the` \
      `# host's docker.sock (bind mount + --group-add) and podman.sock` \
      `# (already covered by the existing XDG_RUNTIME_DIR mount, plus` \
      `# CONTAINER_HOST) into the container. Keeping storage host-side` \
      `# avoids duplicating potentially many-GB image/container state.` \
      docker.io \
      podman \
      `# --- lua ide ---` \
      `# lua-language-server and stylua are prebuilt release binaries,` \
      `# installed below -- only the interpreter itself comes from apt.` \
      lua5.4 \
      `# --- python/ruby/js glue-script tier ---` \
      `# Interpreters/runtimes only -- pyright, ruff, ruby-lsp, rubocop,` \
      `# typescript-language-server, prettier, oxlint are all installed` \
      `# below via npm/gem/binary release, not apt. No pip/poetry/conda,` \
      `# no rvm/rbenv, no node_modules-based/per-project bundler workflow --` \
      `# deliberately scoped to editing/linting isolated scripts, not` \
      `# developing applications in these languages (see README.md's` \
      `# "Language grouping philosophy"). The one exception: the bundler` \
      `# gem itself (installed below, alongside ruby-lsp/rubocop) -- not` \
      `# for per-project Gemfiles, but because ruby-lsp's own internal` \
      `# bootstrap hard-requires the \`bundle\` executable regardless of` \
      `# project structure (see the comment above the bundler RUN step).` \
      `# libyaml-dev is psych's (a transitive ruby-lsp dependency) native-` \
      `# extension build requirement for that same bootstrap.` \
      python3 \
      ruby \
      ruby-dev \
      libyaml-dev \
      adwaita-icon-theme \
      fontconfig \
      fonts-dejavu-core \
      fonts-firacode \
      fonts-jetbrains-mono \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${ZSHDB_VERSION}" https://github.com/rocky/zshdb.git /tmp/zshdb \
    && cd /tmp/zshdb \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && rm -rf /tmp/zshdb

RUN npm install -g bash-language-server@5.6.0

RUN npm install -g \
      pyright@1.1.411 \
      typescript-language-server@5.3.0 \
      typescript@6.0.3 \
      prettier@3.9.5 \
      oxlint@1.74.0
RUN gem install --no-document ruby-lsp:0.24.1 rubocop:1.88.2 bundler

# ruby-lsp's exe/ruby-lsp (see its own source) only runs its internal
# bundler bootstrap -- which shells out to `bundle` and crashes with
# Errno::ENOENT if it isn't installed -- when BUNDLE_GEMFILE is unset. If
# BUNDLE_GEMFILE *is* set, it instead assumes the caller already invoked
# it via `bundle exec` and skips straight to loading its own libraries
# using whatever gems are currently active, which (without an actual
# `bundle exec`) just means "whatever's the highest-installed version of
# each gem" -- for this image, that was rbs 4.0.3, which has an
# unrelated load-order bug (`Pathname()` used before `require "pathname"`
# runs) that crashes ruby-lsp on every startup. So this needs both parts
# together, mirrored in lsp-ruby-lsp-use-bundler in config.el: a fixed,
# pre-built, offline bundle (pinned to the exact gem versions installed
# above, plus rbs pinned below that bug) that `bundle exec ruby-lsp`
# activates, pointed to globally so every ruby-mode buffer reuses it
# regardless of which directory it's opened from -- instead of ruby-lsp
# writing its own `.ruby-lsp/Gemfile` into whatever project happens to be
# open and hitting the network to resolve unpinned gem versions on every
# fresh container.
RUN mkdir -p /opt/ruby-lsp \
    && printf 'source "https://rubygems.org"\ngem "ruby-lsp", "0.24.1"\ngem "debug"\ngem "rbs", "3.10.4"\ngem "rubocop", "1.88.2"\n' > /opt/ruby-lsp/Gemfile \
    && BUNDLE_GEMFILE=/opt/ruby-lsp/Gemfile bundle install
# Global on purpose, matching this image's "no per-project bundler
# workflow" scope (see the apt-package comment above): a manual `bundle
# install`/`bundle exec` run by hand in a container shell against some
# other Gemfile would also pick this up rather than that project's own --
# out of scope for what this glue-script tier is for.
ENV BUNDLE_GEMFILE=/opt/ruby-lsp/Gemfile

# nushell ships its own LSP server behind `nu --lsp` (nu-lsp), so this is the
# only install step nushell support needs -- no separate language-server
# package. Prebuilt release tarball rather than cargo: no Rust toolchain is
# otherwise present in this image. Just the `nu` binary is kept; the bundled
# nu_plugin_* binaries, LICENSE, and README aren't needed here.
RUN curl -fsSL "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/nu.tar.gz \
    && echo "${NU_SHA256}  /tmp/nu.tar.gz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/nu.tar.gz \
    && install -m 755 "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu/nu" /usr/local/bin/nu \
    && rm -rf /tmp/nu.tar.gz "/tmp/nu-${NU_VERSION}-x86_64-unknown-linux-gnu"

RUN userdel ubuntu || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && mkdir -p /home/${USERNAME}/.config/emacs \
    && mkdir -p /home/${USERNAME}/.local/share/fonts \
    && useradd -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /nix /nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.local/state/nix /home/${USERNAME}/.local/state/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/nix /home/${USERNAME}/.config/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/direnv /home/${USERNAME}/.config/direnv

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

RUN ln -sf "/home/${USERNAME}/.local/state/nix/profiles/profile" "/home/${USERNAME}/.nix-profile"

# godef omitted: dead project (last release 2020); golang.org/x/tools dep frozen at pre-1.21 panics on Go 1.26+.
# SPC m h . remapped to lsp-describe-thing-at-point in go-keybindings.el.
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
    | sh -s -- -b "$(go env GOPATH)/bin" v2.11.4 \
    && go install golang.org/x/tools/gopls@v0.22.0 \
    && go install github.com/go-delve/delve/cmd/dlv@v1.26.3 \
    && go install github.com/x-motemen/gore/cmd/gore@v0.6.0 \
    && go install github.com/fatih/gomodifytags@v1.16.0 \
    && go install github.com/cweill/gotests/gotests@latest

RUN cd /home/${USERNAME} \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts \
    && git checkout "${POWERLINE_FONTS_COMMIT}" \
    && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && mkdir -p /home/${USERNAME}/.local/share/fonts/truetype/source-code-pro \
    && wget -q https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/variable-fonts.tar.gz \
         -O /tmp/source-code-pro.tar.gz \
    && echo "2c55c413bab7d51f252659c63ba65624653dd03c1c64f0c16ece6973e5ae9a821e3675e04bbace263ceeaf71875538197071018761e00351359c876d7ad89fd6  /tmp/source-code-pro.tar.gz" \
         | sha512sum -c - \
    && tar xz --strip-components=1 -C ~/.local/share/fonts/truetype/source-code-pro \
         -f /tmp/source-code-pro.tar.gz \
    && rm /tmp/source-code-pro.tar.gz \
    && curl -fsSL "https://raw.githubusercontent.com/rainstormstudio/nerd-icons.el/${NERD_ICONS_COMMIT}/fonts/NFM.ttf" \
         -o /home/${USERNAME}/.local/share/fonts/NFM.ttf \
    && echo "${NFM_SHA256}  /home/${USERNAME}/.local/share/fonts/NFM.ttf" | sha256sum -c - \
    && fc-cache -fv

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

# nushell-ts-mode (packages.el) needs the 'nu tree-sitter grammar compiled and
# on disk before Doom ever loads it -- its own file only registers .nu files
# in auto-mode-alist inside a (when (treesit-ready-p 'nu) ...) form, so this
# has to happen at build time, not deferred to a lazy runtime fetch (no
# network required at container start, matching this image's other tooling).
# -Q skips loading any init file; this is pure vanilla Emacs treesit, nothing
# Doom-specific. gcc/git are already installed above -- tree-sitter-nu is
# plain C (parser.c/scanner.c), no C++ compiler needed. Explicit OUT-DIR:
# Doom redirects its own grammar search path to ~/.config/emacs/.local/cache/
# tree-sitter (not vanilla Emacs's ~/.config/emacs/tree-sitter default), so
# the grammar has to land there directly or Doom's own Emacs won't find it,
# confirmed live via Doom's own "language grammar ... unavailable" warning.
RUN emacs --batch -Q --eval "(progn \
      (setq treesit-language-source-alist '((nu \"https://github.com/nushell/tree-sitter-nu\" nil \"src\"))) \
      (treesit-install-language-grammar 'nu \"/home/${USERNAME}/.config/emacs/.local/cache/tree-sitter\"))"

# cmake-language-server 0.1.11 (unmaintained since Jan 2025, per its repo's
# own commit history) declares `requires-python <3.14`. Ubuntu 24.04's own
# system Python is 3.12 (confirmed, not assumed), so this port shouldn't
# actually hit the failure the aarch64/26.04 port did (whose system Python
# is 3.14.4) -- applied here anyway for parity and as insurance against a
# future Python bump. --ignore-requires-python installs it regardless of
# the declared cap, but its own loose `pygls>=1.1.1` constraint can still
# resolve the newest pygls (2.x), which removed `LanguageServer` from
# `pygls.server` as a breaking change (confirmed live on the aarch64 port:
# ImportError at runtime, not just an overcautious version cap). Pinning
# back to pygls 1.3.1 (the last 1.x release) via `pipx inject` restores the
# API cmake-language-server expects. conan needs neither workaround.
RUN pipx install cmake-language-server=="${CMAKE_LANGUAGE_SERVER_VERSION}" --pip-args="--ignore-requires-python" \
    && pipx inject cmake-language-server pygls==1.3.1 --force \
    && pipx install conan=="${CONAN_VERSION}"

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# vcpkg has no apt package or standalone release binary for the tool itself --
# it's meant to live as a clone alongside your projects, so this clones it to
# a stable, well-known location instead and exposes it on PATH. Bootstrap
# fetches a prebuilt vcpkg-tool release when one matches this arch, falling
# back to compiling from source (needs cmake/ninja-build/g++, already
# installed above) -- confirmed both paths' prerequisites (curl/zip/unzip/
# tar/cmake/git) directly against bootstrap.sh rather than assumed.
RUN git clone --depth 1 --branch "${VCPKG_VERSION}" https://github.com/microsoft/vcpkg.git /home/${USERNAME}/vcpkg \
    && /home/${USERNAME}/vcpkg/bootstrap-vcpkg.sh -disableMetrics
ENV VCPKG_ROOT=/home/${USERNAME}/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"

# nupm (nushell/nupm) is nushell's own official package manager -- unlike
# vcpkg/Conan, it has no apt/pip/tagged-release install path at all: it's a
# self-hosted Nushell module you clone and `use`, which can then install
# itself and other packages. It's also explicitly marked "experimentation
# stage, not for serious use" by its own maintainers, and warns it may need
# nightly Nushell rather than the latest stable -- confirmed live in a
# throwaway container that this pinned commit (whose own CI tests against
# nu 0.114.0, one patch behind our pinned 0.114.1) bootstraps and installs
# packages correctly before committing to it here, rather than assumed
# compatible. `--no-confirm` and pre-creating $NUPM_HOME sidestep an
# interactive first-run prompt that would otherwise hang a non-interactive
# build. Only nupm itself lives here, same as vcpkg/Conan above -- a
# specific package it can install (nutest, or anything else) belongs to
# whichever project actually needs it, installed there via nupm, not baked
# into every image regardless of use.
#
# `nupm install <path> --path` needs <path> to be the directory that
# directly contains nupm.nuon (the checkout root, since this pinned
# commit's own "Migrate to New Commands" restructuring keeps nupm.nuon at
# the repo root with the actual module code nested one level down in
# nupm/) -- passing the bare word "nupm" here (as nupm's own README
# self-install example does) only works by coincidence when the checkout
# happens to be cloned into a directory literally named "nupm", since it's
# resolved as a relative path from CWD, not a package name lookup.
# Confirmed live after that exact mismatch broke this build once already.
RUN mkdir -p /home/${USERNAME}/.config/nushell/nupm \
    && git clone https://github.com/nushell/nupm.git /home/${USERNAME}/.cache/nupm-src \
    && cd /home/${USERNAME}/.cache/nupm-src && git checkout "${NUPM_COMMIT}" \
    && nu -c "use /home/${USERNAME}/.cache/nupm-src/nupm; nupm install /home/${USERNAME}/.cache/nupm-src --force --path --no-confirm" \
    && rm -rf /home/${USERNAME}/.cache/nupm-src \
    && echo '$env.NU_LIB_DIRS = ($env.NU_LIB_DIRS? | default [] | append (\"/home/'"${USERNAME}"'/.config/nushell/nupm/modules\" | path expand))' >> /home/${USERNAME}/.config/nushell/env.nu

# lua5.4 (apt) is only the interpreter -- lua-mode's REPL/execute-buffer
# handling shells out to whatever's on PATH matching lua(?:jit)?, and the
# apt package doesn't provide a bare `lua` symlink (Debian/Ubuntu keep
# versioned lua interpreters installable side by side on purpose).
#
# Installed under the runtime user's own $HOME rather than /usr/local --
# unlike the apt packages and Go tarball earlier in this file (which run
# before the `USER ${USERNAME}` switch, as root), everything from vcpkg
# onward in this file runs *after* that switch, so it only has write
# access within its own home directory. vcpkg/conan/nupm already follow
# this (installed under /home/${USERNAME}/...); ~/.local/bin is already
# on PATH (see the ENV PATH line above), so no new PATH entry is needed.
RUN mkdir -p /home/${USERNAME}/.local/bin \
    && ln -s /usr/bin/lua5.4 /home/${USERNAME}/.local/bin/lua

# lua-language-server ships as a self-contained directory tree (bin/,
# locale/, main.lua, ...), not a single relocatable binary -- the archive
# has to be extracted whole, not just the binary copied out. Installed to
# a fixed, explicit path and wired via `lsp-clients-lua-language-server-bin`
# in config.el rather than relying on lsp-mode's own default install-dir
# convention (a `.cache/lsp/` path under $EMACSDIR that shifts across
# lsp-mode versions) -- explicit here is more robust than betting on
# hitting a moving default correctly.
RUN curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-x64.tar.gz" -o /tmp/lua-ls.tar.gz \
    && echo "${LUA_LANGUAGE_SERVER_SHA256}  /tmp/lua-ls.tar.gz" | sha256sum -c - \
    && mkdir -p /home/${USERNAME}/.local/lib/lua-language-server \
    && tar -C /home/${USERNAME}/.local/lib/lua-language-server -xzf /tmp/lua-ls.tar.gz \
    && rm /tmp/lua-ls.tar.gz

# stylua is a single self-contained binary (Rust) -- no Rust toolchain
# needed to install it, matching the nu/vcpkg precedent of pulling a
# prebuilt release rather than building from source for a one-binary tool.
RUN curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" -o /tmp/stylua.zip \
    && echo "${STYLUA_SHA256}  /tmp/stylua.zip" | sha256sum -c - \
    && unzip -q /tmp/stylua.zip -d /home/${USERNAME}/.local/bin \
    && chmod +x /home/${USERNAME}/.local/bin/stylua \
    && rm /tmp/stylua.zip

# ruff is a single self-contained binary (Rust), used for both linting
# (flycheck's built-in python-ruff checker, no separate package needed)
# and formatting -- overriding apheleia's own default of `black` for
# python-mode (see config.el) so this is the only Python tool needed,
# rather than installing black too via pipx alongside it. Checksum here
# is ruff's own published .sha256 (confirmed against the real release),
# unlike lua-language-server/stylua above, which don't publish one.
RUN curl -fsSL "https://github.com/astral-sh/ruff/releases/download/${RUFF_VERSION}/ruff-x86_64-unknown-linux-gnu.tar.gz" -o /tmp/ruff.tar.gz \
    && echo "${RUFF_SHA256}  /tmp/ruff.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/ruff.tar.gz -C /tmp \
    && install -m 755 /tmp/ruff-x86_64-unknown-linux-gnu/ruff /home/${USERNAME}/.local/bin/ruff \
    && rm -rf /tmp/ruff.tar.gz /tmp/ruff-x86_64-unknown-linux-gnu

# Global default ruff style (2-space indent, LF line endings, docstring
# code formatting, magic trailing comma left on) -- applies to any lone
# script with no project-level ruff config of its own; a real project's
# pyproject.toml/ruff.toml still takes precedence automatically. See
# ruff-pyproject.toml's own header comment for the exact mechanism.
COPY --chown=${USERNAME}:${USERNAME} ruff-pyproject.toml /home/${USERNAME}/.config/ruff/pyproject.toml

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

COPY --chown=${USERNAME}:${USERNAME} config.el          /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el            /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el        /home/${USERNAME}/.config/doom/packages.el
COPY --chown=${USERNAME}:${USERNAME} shell-config.el        /home/${USERNAME}/.config/doom/shell-config.el
COPY --chown=${USERNAME}:${USERNAME} sh-keybindings.el     /home/${USERNAME}/.config/doom/sh-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} c-keybindings.el      /home/${USERNAME}/.config/doom/c-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} rust-keybindings.el   /home/${USERNAME}/.config/doom/rust-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} zig-keybindings.el    /home/${USERNAME}/.config/doom/zig-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} cmake-keybindings.el  /home/${USERNAME}/.config/doom/cmake-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} docker-keybindings.el /home/${USERNAME}/.config/doom/docker-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} lua-keybindings.el    /home/${USERNAME}/.config/doom/lua-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nix-keybindings.el    /home/${USERNAME}/.config/doom/nix-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} bats-keybindings.el   /home/${USERNAME}/.config/doom/bats-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} bats-config.el        /home/${USERNAME}/.config/doom/bats-config.el
COPY --chown=${USERNAME}:${USERNAME} guile-keybindings.el  /home/${USERNAME}/.config/doom/guile-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-keybindings.el     /home/${USERNAME}/.config/doom/go-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-config.el          /home/${USERNAME}/.config/doom/go-config.el
COPY --chown=${USERNAME}:${USERNAME} nu-keybindings.el     /home/${USERNAME}/.config/doom/nu-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nu-config.el          /home/${USERNAME}/.config/doom/nu-config.el
COPY --chown=${USERNAME}:${USERNAME} global-keybindings.el /home/${USERNAME}/.config/doom/global-keybindings.el

RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/${USERNAME}/.config/emacs/bin/doom env \
    `# force a clean recompile here -- the first sync (before init.el/packages.el` \
    `# were copied in) may have already built some of these packages against a` \
    `# different module/package set. Reusing that build/ output risks compiled` \
    `# .elc files silently going stale relative to a package's straight-checked-out` \
    `# .el source. Precautionary insurance around the two-stage-sync design below,` \
    `# not a fix for any specific bug we've confirmed -- see BUILDLOG.md 2026-07-14` \
    `# for a bytecode-staleness theory chased and ruled out this same session.` \
    && rm -rf /home/${USERNAME}/.config/emacs/.local/straight/build-* \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

CMD ["emacs"]
