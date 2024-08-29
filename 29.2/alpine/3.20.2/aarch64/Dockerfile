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
    gnupg \
    libgccjit \
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
 && rm -rf /var/cache/apk/*

# useradd is not part of Alpine, use adduser instead
RUN mkdir -p /home/$username/.emacs.d \
    && mkdir -p /home/$username/.doom.d \
    && mkdir -p /home/$username/.local/share/fonts \
    && mkdir -p /home/$username/.local/share/coursier/bin \
    && adduser -u $uid $username -h /home/$username --disabled-password \
    && chown -R $username:$username /home/$username

USER $username

CMD ["emacs"]
