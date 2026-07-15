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
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
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
      `# --- cli live troubleshooting tools ---` \
      aspell \
      fd-find \
      iputils-ping \
      openssh-client \
      ripgrep \
      vim \
      `# --- native elisp compilation ---` \
      libgccjit-13-dev \
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
      `# --- fonts ---` \
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

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

COPY --chown=${USERNAME}:${USERNAME} config.el          /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el            /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el        /home/${USERNAME}/.config/doom/packages.el
COPY --chown=${USERNAME}:${USERNAME} shell.el               /home/${USERNAME}/.config/doom/shell.el
COPY --chown=${USERNAME}:${USERNAME} sh-keybindings.el     /home/${USERNAME}/.config/doom/sh-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} c-keybindings.el      /home/${USERNAME}/.config/doom/c-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} rust-keybindings.el   /home/${USERNAME}/.config/doom/rust-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} zig-keybindings.el    /home/${USERNAME}/.config/doom/zig-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} cmake-keybindings.el  /home/${USERNAME}/.config/doom/cmake-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} lua-keybindings.el    /home/${USERNAME}/.config/doom/lua-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nix-keybindings.el    /home/${USERNAME}/.config/doom/nix-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} bats-keybindings.el   /home/${USERNAME}/.config/doom/bats-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} guile-keybindings.el  /home/${USERNAME}/.config/doom/guile-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-keybindings.el     /home/${USERNAME}/.config/doom/go-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} go-config.el          /home/${USERNAME}/.config/doom/go-config.el
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
