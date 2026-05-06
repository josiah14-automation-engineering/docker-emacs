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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

COPY --chown=${USERNAME}:${USERNAME} config.el          /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el            /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el        /home/${USERNAME}/.config/doom/packages.el
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
