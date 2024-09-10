FROM josiah14/emacs:29.2-alpine-edge-dev
from alpine:edge

ARG username
ARG uid
ARG fullname
ARG email

COPY --from=0 /usr/local /usr/local

RUN apk add \
    curl \
    gawk \
    git \
    gnupg \
    ripgrep \
    bash \
    findutils \
    coreutils \
    libgccjit \
    gcc \
    make \
    imagemagick \
    iputils-ping \
    aspell \
    libacl \
    alsa-lib \
    libcanberra-gtk3 \
    dbus-libs \
    giflib \
    gnutls \
    gpm \
    gpm-libs \
    gtk+3.0 \
    jansson \
    jpeg \
    libjpeg \
    lcms2 \
    liblockfile \
    m17n-lib --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    libm17n-core --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    ncurses-libs \
    libncurses++ \
    tiff \
    libxaw \
    libwebpdecoder \
    libxml2 \
    openssh-client-default \
    texinfo \
    wget \
    libxaw3d \
    xcb-util \
    zlib \
    fontconfig \
    ttf-dejavu \
    adwaita-icon-theme \
    font-fira-code \
    font-jetbrains-mono \
    fontconfig \
 && rm -rf /var/cache/apk/*

# useradd is not part of Alpine, use adduser instead
RUN mkdir -p /home/$username/.emacs.d \
    && mkdir -p /home/$username/.doom.d \
    && mkdir -p /home/$username/.local/share/fonts \
    && adduser -u $uid $username -h /home/$username --disabled-password \
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
    && fc-cache -fv && sleep 3 \
    # && mkdir -p ~/.local/share/fonts/truetype/cascadia-code \
    # && wget -qO- https://github.com/microsoft/cascadia-code/releases/download/v2307.01/CascadiaCode-2307.01.zip -O /tmp/cascadia-code.zip \
    # && unzip /tmp/cascadia-code.zip -d ~/.local/share/fonts/truetype/cascadia-code \
    # && rm /tmp/cascadia-code.zip \
    # && fc-cache -fv \
    && mkdir -p /home/$username/.config/emacs && chown -R $username:$username /home/$username/.config/emacs

RUN git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$username/.config/emacs
    # && /home/$username/.emacs.d/bin/doom env --help \
    # && /home/$username/.config/emacs/bin/doom sync --no-config --no-env --yes --debug-init

CMD ["emacs"]
