FROM josiah14/emacs:30.2-m2-ubuntu-26.04-dev AS emacs-build

FROM ubuntu:26.04 AS go-build
ARG GO_VERSION=1.26.3
ARG GO_SHA256=9d89a3ea57d141c2b22d70083f2c8459ba3890f2d9e818e7e933b75614936565
RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates curl \
    && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" -o /tmp/go.tar.gz \
    && echo "${GO_SHA256} /tmp/go.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

FROM josiah14/nix:2.34.7-ubuntu-26.04 AS nix-source

FROM josiah14/guix:1.5.0-ubuntu-26.04 AS guix-source

FROM josiah14/chez:10.4.1-ubuntu-26.04 AS chez-source

FROM josiah14/gambit:4.9.7-ubuntu-26.04 AS gambit-source

FROM josiah14/gerbil:0.18.2-ubuntu-26.04 AS gerbil-source

# Build Doom separately so intermediate native-comp output stays out of the final image.
FROM ubuntu:26.04 AS doom-build

ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG FULLNAME
ARG EMAIL
ARG DOOM_REPO=https://github.com/doomemacs/doomemacs
ARG DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:${PATH}"

COPY --from=emacs-build /usr/local /usr/local

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean \
    && apt-get update -y \
    && apt-get install -y \
    `# --- troubleshooting tools ---` \
    aspell \
    ca-certificates \
    curl \
    fd-find \
    git \
    iputils-ping \
    openssh-client \
    ripgrep \
    sudo \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    `# --- native elisp compilation ---` \
    libgccjit-15-dev \
    `# --- tree-sitter grammar compilation (nushell-ts-mode) ---` \
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
    libgtk-3-0t64 \
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
    libgnutls30t64 \
    libjansson4 \
    liblockfile-bin \
    libtree-sitter0.25 \
    libxml2-16 \
    zlib1g \
    `# --- shell ide ---` \
    autoconf \
    automake \
    bats \
    make \
    nodejs \
    npm \
    fish \
    ksh \
    zsh \
    `# --- c/c++/cmake ide ---` \
    clang \
    clangd \
    clang-format \
    cmake \
    g++ \
    gdb \
    ninja-build \
    strace \
    pipx \
    `# --- container clients ---` \
    docker.io \
    podman \
    `# --- rust ide ---` \
    libssl-dev \
    pkg-config \
    `# --- lua ide ---` \
    lua5.4 \
    `# --- scripting languages ---` \
    python3-debugpy \
    ruby-dev \
    libyaml-dev \
    `# --- guile/guix ---` \
    netbase \
    `# --- fonts ---` \
    adwaita-icon-theme \
    fontconfig \
    fonts-dejavu-core \
    fonts-firacode \
    fonts-jetbrains-mono \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN userdel ubuntu || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && mkdir -p /home/${USERNAME}/.config/emacs \
    && mkdir -p /home/${USERNAME}/.local/share/fonts \
    && useradd -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} \
    && mkdir -p /etc/sudoers.d \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && groupadd --system guixbuild \
    && for i in $(seq -w 1 10); do \
         useradd -g guixbuild -G guixbuild -d /var/empty -s /usr/sbin/nologin \
           -c "Guix build user $i" --system guixbuilder$i; \
       done

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all --tags && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

# Doom expects the Nushell grammar in its private tree-sitter cache before sync.
RUN emacs --batch -Q --eval "(progn \
      (setq treesit-language-source-alist '((nu \"https://github.com/nushell/tree-sitter-nu\" nil \"src\"))) \
      (treesit-install-language-grammar 'nu \"/home/${USERNAME}/.config/emacs/.local/cache/tree-sitter\"))"

COPY --chown=${USERNAME}:${USERNAME} config.el /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el /home/${USERNAME}/.config/doom/packages.el
COPY --chown=${USERNAME}:${USERNAME} all-lisps-config.el /home/${USERNAME}/.config/doom/all-lisps-config.el
COPY --chown=${USERNAME}:${USERNAME} shell-config.el /home/${USERNAME}/.config/doom/shell-config.el
COPY --chown=${USERNAME}:${USERNAME} sh-keybindings.el /home/${USERNAME}/.config/doom/sh-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} c-keybindings.el /home/${USERNAME}/.config/doom/c-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} rust-keybindings.el /home/${USERNAME}/.config/doom/rust-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} cmake-keybindings.el /home/${USERNAME}/.config/doom/cmake-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} docker-keybindings.el /home/${USERNAME}/.config/doom/docker-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} lua-keybindings.el /home/${USERNAME}/.config/doom/lua-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} lua-config.el /home/${USERNAME}/.config/doom/lua-config.el
COPY --chown=${USERNAME}:${USERNAME} python-keybindings.el /home/${USERNAME}/.config/doom/python-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} python-config.el /home/${USERNAME}/.config/doom/python-config.el
COPY --chown=${USERNAME}:${USERNAME} ruby-keybindings.el /home/${USERNAME}/.config/doom/ruby-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} ruby-config.el /home/${USERNAME}/.config/doom/ruby-config.el
COPY --chown=${USERNAME}:${USERNAME} javascript-keybindings.el /home/${USERNAME}/.config/doom/javascript-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} typescript-keybindings.el /home/${USERNAME}/.config/doom/typescript-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nix-keybindings.el /home/${USERNAME}/.config/doom/nix-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} bats-keybindings.el /home/${USERNAME}/.config/doom/bats-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} bats-config.el /home/${USERNAME}/.config/doom/bats-config.el
COPY --chown=${USERNAME}:${USERNAME} guile-keybindings.el /home/${USERNAME}/.config/doom/guile-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} fish-keybindings.el /home/${USERNAME}/.config/doom/fish-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} fish-config.el /home/${USERNAME}/.config/doom/fish-config.el
COPY --chown=${USERNAME}:${USERNAME} asm-config.el /home/${USERNAME}/.config/doom/asm-config.el
COPY --chown=${USERNAME}:${USERNAME} toml-config.el /home/${USERNAME}/.config/doom/toml-config.el
COPY --chown=${USERNAME}:${USERNAME} scheme-config.el /home/${USERNAME}/.config/doom/scheme-config.el
COPY --chown=${USERNAME}:${USERNAME} gerbil-config.el /home/${USERNAME}/.config/doom/gerbil-config.el
COPY --chown=${USERNAME}:${USERNAME} gerbil-keybindings.el /home/${USERNAME}/.config/doom/gerbil-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-keybindings.el /home/${USERNAME}/.config/doom/go-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-config.el /home/${USERNAME}/.config/doom/go-config.el
COPY --chown=${USERNAME}:${USERNAME} nu-keybindings.el /home/${USERNAME}/.config/doom/nu-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nu-config.el /home/${USERNAME}/.config/doom/nu-config.el
COPY --chown=${USERNAME}:${USERNAME} dape-config.el /home/${USERNAME}/.config/doom/dape-config.el
COPY --chown=${USERNAME}:${USERNAME} global-keybindings.el /home/${USERNAME}/.config/doom/global-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} polyglot-keybindings.el /home/${USERNAME}/.config/doom/polyglot-keybindings.el

# Recompile after the project configuration is copied in.
RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && rm -rf /home/${USERNAME}/.config/emacs/.local/straight/build-* \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

# --- Final image ---
FROM ubuntu:26.04

ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG POWERLINE_FONTS_COMMIT=a029626780dd4af32f15a3e708a5b00528c22f1d
ARG NERD_ICONS_COMMIT=1db0b0b9203cf293b38ac278273efcfc3581a05f
ARG NFM_SHA256=f0f624d9b474bea1662cf7e862d44aebe1ae1f6c7f9cb7a0ca5d0e5ac9561c60
ARG ZSHDB_VERSION=1.1.4
ARG NU_VERSION=0.114.1
ARG NU_SHA256=39944812ee619736fd50828e66c96b91747c1e189ccddac89c3ac1a02e0614f2
ARG CMAKE_LANGUAGE_SERVER_VERSION=0.1.11
ARG CONAN_VERSION=2.30.0
ARG VCPKG_VERSION=2026.06.24
ARG NUPM_COMMIT=9a28419bf91aadc58999d83e0f6ef8d9dbfa7d9f
ARG LUA_LANGUAGE_SERVER_VERSION=3.18.2
ARG LUA_LANGUAGE_SERVER_SHA256=273af33f26f4a1143f27c96d9f9e1188aba619c71e0807042134f66b4bd27f24
ARG STYLUA_VERSION=2.5.2
ARG STYLUA_SHA256=0ef2ebf0b7e5a652b65c4cb96c6d9ffb3981a98547de3c764465bbf54a8d761a
ARG LOCAL_LUA_DEBUGGER_VERSION=release-0.3.3
ARG RUFF_VERSION=0.15.22
ARG RUFF_SHA256=54ec426d839d7cea1096e9ea1c5486fd2f3df62ee6cfd71dc090b18f99bebd90
ARG RUST_VERSION=1.97.1
ARG RACKET_VERSION=9.2
ARG RACKET_SHA256=ea43b82866024ec6af1e811e45857ff9859ae0a17a7f21da9c04e60102f621e9
ARG ZIG_VERSION=0.16.0
ARG ZIG_SHA256=ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17
ARG ZLS_VERSION=0.16.0
ARG ZLS_SHA256=430cd293d201eb70ae2519dbc96c854bf8791b8df7fc9392e8d2dc9680a2bed7
ARG TAPLO_VERSION=0.10.0
ARG TAPLO_SHA256=033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
ENV NODE_PATH=/usr/local/lib/node_modules
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:${PATH}"
ENV GOPATH=/home/${USERNAME}/go
# Apple M2 baseline: ARMv8.6-A with crypto extensions.
ENV GOARM64=v8.6,crypto
ENV GOTOOLCHAIN=auto
ENV PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"

COPY --from=emacs-build /usr/local /usr/local
COPY --from=go-build /usr/local/go /usr/local/go

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean \
    && apt-get update -y \
    && apt-get install -y \
    `# --- troubleshooting tools ---` \
    aspell \
    ca-certificates \
    curl \
    fd-find \
    git \
    iputils-ping \
    openssh-client \
    ripgrep \
    sudo \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    `# --- native elisp compilation ---` \
    libgccjit-15-dev \
    `# --- tree-sitter grammar compilation (nushell-ts-mode) ---` \
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
    libgtk-3-0t64 \
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
    libgnutls30t64 \
    libjansson4 \
    liblockfile-bin \
    libtree-sitter0.25 \
    libxml2-16 \
    zlib1g \
    `# --- shell ide ---` \
    autoconf \
    automake \
    bats \
    make \
    nodejs \
    npm \
    shellcheck \
    fish \
    ksh \
    zsh \
    `# --- c/c++/cmake ide ---` \
    clang \
    clangd \
    clang-format \
    cmake \
    g++ \
    gdb \
    lldb \
    ninja-build \
    strace \
    pipx \
    `# --- container clients ---` \
    docker.io \
    podman \
    `# --- rust ide ---` \
    libssl-dev \
    pkg-config \
    `# --- lua ide ---` \
    lua5.4 \
    `# --- scripting languages ---` \
    python3-debugpy \
    ruby-dev \
    libyaml-dev \
    `# --- guile/guix ---` \
    netbase \
    `# --- fonts ---` \
    adwaita-icon-theme \
    fontconfig \
    fonts-dejavu-core \
    fonts-firacode \
    fonts-jetbrains-mono \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Prevent LLDB from hanging on unreachable Ubuntu debuginfod servers.
ENV DEBUGINFOD_URLS=""

# Install shell, JavaScript, and Ruby tooling while still root.
RUN git clone --depth 1 --branch "${ZSHDB_VERSION}" https://github.com/rocky/zshdb.git /tmp/zshdb \
    && cd /tmp/zshdb \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/zshdb \
    && npm install -g \
    bash-language-server@5.6.0 \
    pyright@1.1.411 \
    typescript@5.9.3 \
    typescript-language-server@5.3.0 \
    prettier@3.9.5 \
    oxlint@1.74.0 \
    fish-lsp@1.1.4 \
    && gem install --no-document ruby-lsp:0.24.1 rubocop:1.88.2 bundler \
    && mkdir -p /opt/ruby-lsp \
    && printf 'source "https://rubygems.org"\ngem "ruby-lsp", "0.24.1"\ngem "debug"\ngem "rbs", "3.10.4"\ngem "rubocop", "1.88.2"\n' > /opt/ruby-lsp/Gemfile \
    && BUNDLE_GEMFILE=/opt/ruby-lsp/Gemfile bundle install

# Reuse one pinned Ruby LSP bundle for every project.
ENV BUNDLE_GEMFILE=/opt/ruby-lsp/Gemfile

# Install only the Nushell binary from the release archive.
RUN curl -fsSL "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-aarch64-unknown-linux-gnu.tar.gz" -o /tmp/nu.tar.gz \
    && echo "${NU_SHA256} /tmp/nu.tar.gz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/nu.tar.gz \
    && install -m 755 "/tmp/nu-${NU_VERSION}-aarch64-unknown-linux-gnu/nu" /usr/local/bin/nu \
    && rm -rf /tmp/nu.tar.gz "/tmp/nu-${NU_VERSION}-aarch64-unknown-linux-gnu"

# Create the runtime user and Guix build-user pool.
RUN userdel ubuntu || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && mkdir -p /home/${USERNAME}/.config/emacs \
    && mkdir -p /home/${USERNAME}/.local/share/fonts \
    && useradd -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} \
    && mkdir -p /etc/sudoers.d \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && groupadd --system guixbuild \
    && for i in $(seq -w 1 10); do \
         useradd -g guixbuild -G guixbuild -d /var/empty -s /usr/sbin/nologin \
           -c "Guix build user $i" --system guixbuilder$i; \
       done

COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /nix /nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.local/state/nix /home/${USERNAME}/.local/state/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/nix /home/${USERNAME}/.config/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/direnv /home/${USERNAME}/.config/direnv
COPY --from=guix-source --chown=${USERNAME}:${USERNAME} /gnu /gnu
COPY --from=guix-source --chown=${USERNAME}:${USERNAME} /var/guix /var/guix
# Copy each self-contained Scheme toolchain; standalone Gambit provides `gsi`.
COPY --from=chez-source --chown=${USERNAME}:${USERNAME} /opt/chez /opt/chez
COPY --from=gambit-source --chown=${USERNAME}:${USERNAME} /opt/gambit /opt/gambit
COPY --from=gerbil-source --chown=${USERNAME}:${USERNAME} /opt/gerbil /opt/gerbil
ENV PATH="/opt/chez/bin:/opt/gambit/bin:/opt/gerbil/bin:${PATH}"

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

# Wire the copied Nix, Guix, and Guile profiles into the runtime user's PATH.
RUN ln -sf "/home/${USERNAME}/.local/state/nix/profiles/profile" "/home/${USERNAME}/.nix-profile" \
    && mkdir -p "/home/${USERNAME}/.local/bin" "/home/${USERNAME}/.config/guix" \
    && ln -sf "/var/guix/profiles/per-user/root/current-guix" "/home/${USERNAME}/.config/guix/current" \
    && GUIX_PROFILE="$(readlink -f /var/guix/profiles/per-user/root/current-guix)" \
    && GUILE_STORE_DIR="$(find /gnu/store -maxdepth 1 -iname '*-guile-3.*' -printf '%f\n' | head -n 1)" \
    && for bin in guix; do \
         ln -sf "${GUIX_PROFILE}/bin/${bin}" "/home/${USERNAME}/.local/bin/${bin}"; \
       done \
    && for bin in guile guild guile-config; do \
         ln -sf "/gnu/store/${GUILE_STORE_DIR}/bin/${bin}" "/home/${USERNAME}/.local/bin/${bin}"; \
       done

# Go development tools. godef is omitted because it is incompatible with current Go.
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
    && echo "0c789bd5c8aac80f3801039edea1205ce1f2dd22b40506a11ebc698eab8b7273 /tmp/source-code-pro.tar.gz" | sha256sum -c - \
    && tar -C /home/${USERNAME}/.local/share/fonts/truetype/source-code-pro \
    --strip-components=1 -xzf /tmp/source-code-pro.tar.gz \
    && rm /tmp/source-code-pro.tar.gz \
    && curl -fsSL "https://raw.githubusercontent.com/rainstormstudio/nerd-icons.el/${NERD_ICONS_COMMIT}/fonts/NFM.ttf" \
    -o /home/${USERNAME}/.local/share/fonts/NFM.ttf \
    && echo "${NFM_SHA256} /home/${USERNAME}/.local/share/fonts/NFM.ttf" | sha256sum -c - \
    && fc-cache -fv

# cmake-language-server needs pygls 1.x and a relaxed Python version check.
RUN pipx install cmake-language-server=="${CMAKE_LANGUAGE_SERVER_VERSION}" --pip-args="--ignore-requires-python" \
    && pipx inject cmake-language-server pygls==1.3.1 --force \
    && pipx install conan=="${CONAN_VERSION}"

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# vcpkg installs its executable at the checkout root.
RUN git clone --depth 1 --branch "${VCPKG_VERSION}" https://github.com/microsoft/vcpkg.git /home/${USERNAME}/vcpkg \
    && /home/${USERNAME}/vcpkg/bootstrap-vcpkg.sh -disableMetrics
ENV VCPKG_ROOT=/home/${USERNAME}/vcpkg
ENV PATH="${VCPKG_ROOT}:${PATH}"

# Bootstrap nupm from its pinned checkout; packages remain project-local.
RUN mkdir -p /home/${USERNAME}/.config/nushell/nupm \
    && git clone https://github.com/nushell/nupm.git /home/${USERNAME}/.cache/nupm-src \
    && cd /home/${USERNAME}/.cache/nupm-src && git checkout "${NUPM_COMMIT}" \
    && nu -c "use /home/${USERNAME}/.cache/nupm-src/nupm; nupm install /home/${USERNAME}/.cache/nupm-src --force --path --no-confirm" \
    && rm -rf /home/${USERNAME}/.cache/nupm-src \
    && printf '\n$env.NU_LIB_DIRS = ($env.NU_LIB_DIRS? | default [] | append ("/home/'"${USERNAME}"'/.config/nushell/nupm/modules" | path expand))\n' >> /home/${USERNAME}/.config/nushell/env.nu

# Add unversioned interpreter names expected by Emacs tooling.
RUN mkdir -p /home/${USERNAME}/.local/bin \
    && ln -s /usr/bin/lua5.4 /home/${USERNAME}/.local/bin/lua \
    && ln -s /usr/bin/python3 /home/${USERNAME}/.local/bin/python

# Lua language server, formatter, and debugger.
RUN curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LANGUAGE_SERVER_VERSION}/lua-language-server-${LUA_LANGUAGE_SERVER_VERSION}-linux-arm64.tar.gz" -o /tmp/lua-ls.tar.gz \
    && echo "${LUA_LANGUAGE_SERVER_SHA256} /tmp/lua-ls.tar.gz" | sha256sum -c - \
    && mkdir -p /home/${USERNAME}/.local/lib/lua-language-server \
    && tar -C /home/${USERNAME}/.local/lib/lua-language-server -xzf /tmp/lua-ls.tar.gz \
    && rm /tmp/lua-ls.tar.gz \
    && curl -fsSL "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-aarch64.zip" -o /tmp/stylua.zip \
    && echo "${STYLUA_SHA256} /tmp/stylua.zip" | sha256sum -c - \
    && unzip -q /tmp/stylua.zip -d /home/${USERNAME}/.local/bin \
    && chmod +x /home/${USERNAME}/.local/bin/stylua \
    && rm /tmp/stylua.zip \
    && git clone --depth 1 --branch "${LOCAL_LUA_DEBUGGER_VERSION}" https://github.com/tomblind/local-lua-debugger-vscode.git /tmp/lldbg-src \
    && cd /tmp/lldbg-src \
    && npm install \
    && npm run build-debugger \
    && npm run build-extension \
    && npm install --omit=dev \
    && mkdir -p /home/${USERNAME}/.local/lib/local-lua-debugger-vscode \
    && cp -r /tmp/lldbg-src/. /home/${USERNAME}/.local/lib/local-lua-debugger-vscode/ \
    && rm -rf /tmp/lldbg-src

# Install Ruff from its checksummed release archive.
RUN curl -fsSL "https://github.com/astral-sh/ruff/releases/download/${RUFF_VERSION}/ruff-aarch64-unknown-linux-gnu.tar.gz" -o /tmp/ruff.tar.gz \
    && echo "${RUFF_SHA256} /tmp/ruff.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/ruff.tar.gz -C /tmp \
    && install -m 755 /tmp/ruff-aarch64-unknown-linux-gnu/ruff /home/${USERNAME}/.local/bin/ruff \
    && rm -rf /tmp/ruff.tar.gz /tmp/ruff-aarch64-unknown-linux-gnu

# Project Ruff configuration still overrides this user default.
COPY --chown=${USERNAME}:${USERNAME} ruff-pyproject.toml /home/${USERNAME}/.config/ruff/pyproject.toml

# Install the standalone Taplo binary.
RUN curl -fsSL "https://github.com/tamasfe/taplo/releases/download/${TAPLO_VERSION}/taplo-linux-aarch64.gz" -o /tmp/taplo.gz \
    && echo "${TAPLO_SHA256} /tmp/taplo.gz" | sha256sum -c - \
    && gunzip -c /tmp/taplo.gz > /home/${USERNAME}/.local/bin/taplo \
    && chmod +x /home/${USERNAME}/.local/bin/taplo \
    && rm /tmp/taplo.gz

# Rust toolchain and ARM64-built assembly language server.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain "${RUST_VERSION}" --profile default --no-modify-path \
    && /home/${USERNAME}/.cargo/bin/rustup component add rust-analyzer rust-src rustfmt clippy \
    && /home/${USERNAME}/.cargo/bin/cargo install asm-lsp --locked --version 0.10.1
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

# Install current Racket, its language server, Rash, and formatter.
RUN curl -fsSL "https://mirror.racket-lang.org/installers/${RACKET_VERSION}/racket-minimal-${RACKET_VERSION}-aarch64-linux-buster-cs.sh" -o /tmp/racket-installer.sh \
    && echo "${RACKET_SHA256} /tmp/racket-installer.sh" | sha256sum -c - \
    && chmod +x /tmp/racket-installer.sh \
    && echo "0" | /tmp/racket-installer.sh --unix-style --dest /home/${USERNAME}/.local/lib/racket --create-dir \
    && rm /tmp/racket-installer.sh \
    && /home/${USERNAME}/.local/lib/racket/bin/raco pkg install --auto --skip-installed racket-langserver rash fmt
ENV PATH="/home/${USERNAME}/.local/lib/racket/bin:${PATH}"

# Install Zig's full directory tree and the matching ZLS binary.
RUN mkdir -p /home/${USERNAME}/.local/lib/zig \
    && curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-aarch64-linux-${ZIG_VERSION}.tar.xz" -o /tmp/zig.tar.xz \
    && echo "${ZIG_SHA256} /tmp/zig.tar.xz" | sha256sum -c - \
    && tar -C /home/${USERNAME}/.local/lib/zig --strip-components=1 -xJf /tmp/zig.tar.xz \
    && rm /tmp/zig.tar.xz \
    && mkdir -p /tmp/zls-extract \
    && curl -fsSL "https://github.com/zigtools/zls/releases/download/${ZLS_VERSION}/zls-aarch64-linux.tar.xz" -o /tmp/zls.tar.xz \
    && echo "${ZLS_SHA256} /tmp/zls.tar.xz" | sha256sum -c - \
    && tar -C /tmp/zls-extract -xJf /tmp/zls.tar.xz \
    && install -m 755 /tmp/zls-extract/zls /home/${USERNAME}/.local/bin/zls \
    && rm -rf /tmp/zls.tar.xz /tmp/zls-extract
ENV PATH="/home/${USERNAME}/.local/lib/zig:${PATH}"

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

# Copy the completed Doom installation without its build-stage layer history.
COPY --from=doom-build --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/emacs /home/${USERNAME}/.config/emacs
COPY --from=doom-build --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/doom /home/${USERNAME}/.config/doom

RUN doom env

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["emacs"]
