ARG MARCH=skylake
ARG MTUNE=skylake

FROM josiah14/emacs:30.2-${MARCH}-ubuntu-24.04-dev AS emacs-build


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
ARG ZSHDB_VERSION=1.1.4
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:${PATH}"

COPY --from=emacs-build /usr/local /usr/local

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

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

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
    && fc-cache -fv

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

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
COPY --chown=${USERNAME}:${USERNAME} guile-keybindings.el  /home/${USERNAME}/.config/doom/guile-keybindings.el

RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/${USERNAME}/.config/emacs/bin/doom env \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

CMD ["emacs"]
