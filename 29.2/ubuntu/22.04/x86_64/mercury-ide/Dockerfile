FROM josiah14/emacs:29.2-skylake-ubuntu-22.04-dev
FROM ubuntu:22.04

ARG username
ARG uid
ARG fullname
ARG email

COPY --from=0 /usr/local /usr/local

RUN DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get install -y \
      build-essential \
      libffi-dev \
      libffi8ubuntu1 \
      libgmp-dev \
      libicu-dev \
      libgmp10 \
      pkg-config \
      curl \
      gawk \
      git \
      gnupg \
      ripgrep \
      fd-find \
      bash \
      findutils \
      coreutils \
      libgccjit-12-dev \
      gcc \
      g++ \
      make \
      imagemagick \
      iputils-ping \
      aspell \
      libacl1 \
      libasound2 \
      alsa-base \
      bzip2 \
      libcanberra-gtk3-0 \
      dbus \
      x11-utils \
      dbus-x11 \
      libgif7 \
      libgnutls30 \
      libgpm2 \
      libglib2.0-0 \
      libjansson4 \
      libjpeg-turbo8 \
      liblcms2-2 \
      liblockfile-bin \
      libtiff5 \
      libgnutls30 \
      gpm \
      libgpm2 \
      gtk+3.0 \
      libm17n-0 \
      libncurses5 \
      libncurses6 \
      libncursesw6 \
      libncurses-dev \
      libsm6 \
      libtinfo5 \
      libwebpdemux2 \
      libwebp7 \
      libwebp-dev \
      libtree-sitter0 \
      libxext6 \
      libxml2 \
      libxrender1 \
      openssh-client \
      texinfo \
      wget \
      libxaw7 \
      libxcb-util1 \
      zlib1g \
      zlib1g-dev \
      fontconfig \
      fonts-dejavu-core \
      adwaita-icon-theme \
      fonts-firacode \
      fonts-jetbrains-mono \
      fontconfig \
      vim \
    && mkdir -p /etc/apt/keyrings \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# We don't need the default ubuntu user, and that user's uid is likely to conflict
# with the base system's uid, so we delete that user and any files and directories
# associated. Then, create the user and directory that matches the host system's
# current user during the build of the container.
RUN userdel --remove ubuntu || true \
    && mkdir -p /home/$username/.config/emacs \
    && mkdir -p /home/$username/.local/share/fonts \
    && useradd -u $uid $username \
    && chown -R $username:$username /home/$username

USER $username
ENV USER=$username
ENV HOME=/home/$username

RUN cd /home/$username \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && mkdir -p /home/$username/.local/share/fonts/truetype/source-code-pro \
    && wget -qO- https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/variable-fonts.tar.gz \
         | tar xz --strip-components=1 -C ~/.local/share/fonts/truetype/source-code-pro \
    && fc-cache -fv

# 0b2ccac00751dfc2f7628b1a2496727633cc3db5
RUN git clone https://github.com/hlissner/doom-emacs /home/$username/.config/emacs \
    && cd /home/$username/.config/emacs && git fetch --all && git reset --hard fdcab58a1b28a3b2bde23789e2a4c9c1391070b6 \
    && /home/$username/.config/emacs/bin/doom install -! --aot --fonts \
    && /home/$username/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

# This is done down here so that the Doom Emacs configuration can be more easily changed without
# the need to re-clone Doom and re-install the fonts, which takes a long time.
COPY --chown=$username:$username config.el /home/$username/.config/doom/config.el
COPY --chown=$username:$username init.el /home/$username/.config/doom/init.el
COPY --chown=$username:$username packages.el /home/$username/.config/doom/packages.el

RUN sed -i "s/<full-name>/\"$fullname\"/" /home/$username/.config/doom/config.el \
    && sed -i "s/<email-address>/\"$email\"/" /home/$username/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/$username/.config/emacs/bin/doom env --help \
    && /home/$username/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc \
    && cd ~

CMD ["emacs"]
