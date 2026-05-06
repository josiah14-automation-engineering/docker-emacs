ARG MARCH=skylake
ARG MTUNE=skylake

FROM josiah14/emacs:30.2-${MARCH}-ubuntu-24.04-dev AS emacs-build


# --- Zig + ZLS build stage ---
FROM ubuntu:24.04 AS zig-build

ARG MARCH
ARG MTUNE
# TODO: verify these versions and pin sha512 checksums before first build
ARG ZIG_VERSION=0.13.0
ARG ZIG_SHA512=<pin-before-build>
ARG ZLS_VERSION=0.13.0
ARG ZLS_SHA512=<pin-before-build>
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y ca-certificates curl xz-utils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Zig is distributed as a pre-built tarball; no compilation required.
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
         -o zig.tar.xz \
    && echo "${ZIG_SHA512}  zig.tar.xz" | sha512sum -c - \
    && mkdir -p /usr/local/zig \
    && tar -xf zig.tar.xz --strip-components=1 -C /usr/local/zig \
    && rm zig.tar.xz

# ZLS (Zig Language Server) — pre-built binary from GitHub releases.
# Must match ZIG_VERSION exactly; ZLS and Zig are tightly coupled.
# TODO: verify download URL and sha512 for chosen ZLS_VERSION
RUN curl -fsSL "https://github.com/zigtools/zls/releases/download/${ZLS_VERSION}/zls-x86_64-linux.tar.xz" \
         -o zls.tar.xz \
    && echo "${ZLS_SHA512}  zls.tar.xz" | sha512sum -c - \
    && tar -xf zls.tar.xz -C /usr/local/zig \
    && rm zls.tar.xz


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
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

# TODO: pin versions and sha512 checksums for all binary LSP servers before first build
ARG LUA_LS_VERSION=<pin-before-build>
ARG LUA_LS_SHA512=<pin-before-build>
ARG NIL_VERSION=<pin-before-build>
ARG NIL_SHA512=<pin-before-build>
ARG TAPLO_VERSION=<pin-before-build>
ARG TAPLO_SHA512=<pin-before-build>
ARG CODELLDB_VERSION=<pin-before-build>
ARG CODELLDB_SHA512=<pin-before-build>

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:/usr/local/zig:${PATH}"

COPY --from=emacs-build /usr/local /usr/local
COPY --from=zig-build /usr/local/zig /usr/local/zig

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean

RUN apt-get update -y && \
    apt-get install -y \
      ca-certificates curl gawk git gnupg ripgrep fd-find unzip bash \
      findutils coreutils xz-utils tar sudo locales libgccjit-13-dev \
      imagemagick iputils-ping aspell libacl1 libasound2t64 alsa-base \
      bzip2 libcanberra-gtk3-0 dbus x11-utils dbus-x11 libgif7 libgnutls30 \
      libgpm2 gpm libglib2.0-0t64 libjansson4 libjpeg-turbo8 liblcms2-2 \
      liblockfile-bin libtiff6 libgtk-3-0 libm17n-0 libncurses6 libncursesw6 \
      libtinfo6 libsm6 libwebpdemux2 libwebp7 libwebpdecoder3 libtree-sitter0 \
      libxext6 librsvg2-2 libxml2 libxrender1 openssh-client texinfo wget \
      libxaw7 libxcb-util1 zlib1g fonts-dejavu-core adwaita-icon-theme \
      fonts-firacode fonts-jetbrains-mono fontconfig vim \
      gcc g++ clang clangd \
      gdb lldb \
      cmake ninja-build make \
      lua5.4 \
      guile-3.0 \
      nodejs npm \
      python3 python3-pip \
      ruby perl \
      fish \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# cmake-language-server — Python package
RUN pip3 install --break-system-packages cmake-language-server

# bash-language-server — npm package
RUN npm install -g bash-language-server

# lua-language-server — pre-built binary from GitHub releases
# https://github.com/LuaLS/lua-language-server/releases
# TODO: download, verify sha512, extract to /usr/local/bin
RUN echo "TODO: install lua-language-server ${LUA_LS_VERSION}"

# nil — Nix language server, pre-built binary from GitHub releases
# https://github.com/oxalica/nil/releases
# Note: installs only the LSP server; Nix itself is not installed in this image.
# Nix syntax checking and completion work via nil without the Nix daemon.
# TODO: download, verify sha512, install to /usr/local/bin
RUN echo "TODO: install nil ${NIL_VERSION}"

# taplo — TOML language server, pre-built binary from GitHub releases
# https://github.com/tamasfe/taplo/releases
# TODO: download, verify sha512, install to /usr/local/bin
RUN echo "TODO: install taplo ${TAPLO_VERSION}"

# codelldb — DAP debug server for Rust and Zig via lldb
# https://github.com/vadimcn/codelldb/releases
# TODO: download vsix, verify sha512, extract adapter/ to a stable path,
# then point dap-codelldb-extension-path at it in config.el
RUN echo "TODO: install codelldb ${CODELLDB_VERSION}"

RUN userdel ubuntu || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && mkdir -p /home/${USERNAME}/.config/emacs \
    && mkdir -p /home/${USERNAME}/.local/share/fonts \
    && useradd -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

RUN cd /home/${USERNAME} \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts \
    && git checkout a029626780dd4af32f15a3e708a5b00528c22f1d \
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
    && fc-cache -fv

# Rust toolchain via rustup.
# TODO: pin rustup installer sha256 before first build; check https://sh.rustup.rs sha256 at build time.
# rust-analyzer ships as a rustup component; rust-src is needed for accurate
# completion and go-to-definition across the standard library.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
         | sh -s -- -y --no-modify-path --default-toolchain stable \
    && ~/.cargo/bin/rustup component add rust-analyzer rust-src

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

COPY --chown=${USERNAME}:${USERNAME} config.el   /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el     /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el /home/${USERNAME}/.config/doom/packages.el

RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/${USERNAME}/.config/emacs/bin/doom env \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

CMD ["emacs"]
