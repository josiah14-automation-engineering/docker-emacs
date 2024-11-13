FROM josiah14/emacs:29.2-x86_64-ubuntu-22.04-dev
FROM ubuntu:22.04

ARG username
ARG uid
ARG fullname
ARG email

COPY --from=0 /usr/local /usr/local

ENV POETRY_VERSION=1.8.4
ENV POETRY_HOME=/opt/poetry

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
      libncurses5 \
      libncurses6 \
      libncursesw6 \
      libncurses-dev \
      libtinfo5 \
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
      zlib1g-dev \
      fontconfig \
      fonts-dejavu-core \
      adwaita-icon-theme \
      fonts-firacode \
      fonts-jetbrains-mono \
      fontconfig \
      vim \
      python3 \
      python3-pip \
      python3-venv \
    && curl -sSL https://install.python-poetry.org | python3 - \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Running this here because running it as part of the previous command caused filesystem permissions issues.
RUN npm install -g pyright

ENV PATH="${POETRY_HOME}/bin:${PATH}"

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
ENV PATH="${POETRY_HOME}/bin:${PATH}"

RUN cd /home/$username \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && mkdir -p /home/$username/.local/share/fonts/truetype/source-code-pro \
    && wget -qO- https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/variable-fonts.tar.gz \
         | tar xz --strip-components=1 -C ~/.local/share/fonts/truetype/source-code-pro \
    && fc-cache -fv

# 0b2ccac00751dfc2f7628b1a2496727633cc3db5
RUN git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$username/.config/emacs \
    && cd /home/$username/.config/emacs && git reset --hard fdcab58a1b28a3b2bde23789e2a4c9c1391070b6 \
    && /home/$username/.config/emacs/bin/doom install -! --aot --fonts \
    && /home/$username/.config/emacs/bin/doom sync -! -u -j "$(nproc)" --aot --gc

# This is done down here so that the Doom Emacs configuration can be more easily changed without
# the need to re-clone Doom and re-install the fonts, which takes a long time.
COPY config.el /home/$username/.config/doom/config.el
COPY init.el /home/$username/.config/doom/init.el
COPY packages.el /home/$username/.config/doom/packages.el

RUN sed -i "s/<full-name>/\"$fullname\"/" /home/$username/.config/doom/config.el \
    && sed -i "s/<email-address>/\"$email\"/" /home/$username/.config/doom/config.el \
    && /home/$username/.config/emacs/bin/doom env --help \
    && /home/$username/.config/emacs/bin/doom sync -! -u -j "$(nproc)" --aot --gc \
    && cd ~

CMD ["emacs"]
