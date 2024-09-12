FROM josiah14/emacs:29.2-x86_64-ubuntu-22.04-dev
FROM ubuntu:22.04

ARG username
ARG uid
ARG fullname
ARG email

COPY --from=0 /usr/local /usr/local

RUN DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get install -y \
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
      make \
      imagemagick \
      iputils-ping \
      aspell \
      libacl1 \
      libasound2 \
      alsa-base \
      libcanberra-gtk3-0 \
      dbus \
      x11-utils \
      dbus-x11 \
      libgif7 \
      libgnutls30 \
      libgpm2 \
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
      libncurses6 \
      libncursesw6 \
      libwebpdemux2 \
      libwebp7 \
      libwebp-dev \
      libtree-sitter0 \
      libxml2 \
      openssh-client \
      texinfo \
      wget \
      libxaw7 \
      libxcb-util1 \
      zlib1g \
      fontconfig \
      fonts-dejavu-core \
      adwaita-icon-theme \
      fonts-firacode \
      fonts-jetbrains-mono \
      fontconfig \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# We don't need the default ubuntu user, and that user's uid is likely to conflict
# with the base system's uid, so we delete that user and any files and directories
# associated. Then, create the user and directory that matches the host system's
# current user during the build of the container.
RUN userdel --remove ubuntu || true \
    && mkdir -p /home/$username/.config/emacs \
    && mkdir -p /home/$username/.emacs.d \
    && mkdir -p /home/$username/.doom.d \
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
    && wget -qO- https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/variable-fonts.tar.gz | \
         tar xz --strip-components=1 -C ~/.local/share/fonts/truetype/source-code-pro \
    && fc-cache -fv

RUN git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$username/.config/emacs \
    && /home/$username/.config/emacs/bin/doom install --help \
    && /home/$username/.config/emacs/bin/doom install -! -D --aot; cat /tmp//doom.47.0.sh

CMD ["emacs"]
