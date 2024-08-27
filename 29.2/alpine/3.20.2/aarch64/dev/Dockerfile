FROM alpine:edge

# autoconf, automake, and libtool make up Ubuntu autotools
# alsa-lib replaces libasound2
# tiff replaces libotf
RUN apk add autoconf \
    automake \
    libtool \
    build-base \
    alpine-sdk \
    curl \
    git \
    gnupg \
    libgccjit \
    libgccjit-dev \
    gcc \
    imagemagick \
    imagemagick-dev \
    imagemagick-c++ \
    iputils-ping \
    aspell \
    aspell-dev \
    libacl \
    acl-dev \
    alsa-lib \
    alsa-lib-dev \
    libcanberra-gtk3 \
    libcanberra-alsa \
    libcanberra-dev \
    dbus-libs \
    dbus-dev \
    giflib \
    giflib-dev \
    gnutls \
    gnutls-dev \
    gpm \
    gpm-libs\
    gpm-dev\
    gtk+3.0 \
    gtk+3.0-dev \
    jansson \
    jansson-dev \
    jpeg \
    jpeg-dev \
    libjpeg \
    lcms2 \
    lcms2-dev \
    liblockfile \
    liblockfile-dev \
    m17n-lib --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    m17n-lib-dev --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    libm17n-core --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ \
    ncurses-libs \
    ncurses-dev \
    libncurses++ \
    tiff \
    tiff-dev \
    libxaw \
    libxaw-dev \
    libxml2 \
    libxml2-dev \
    openssh-client-default \
    texinfo \
    wget \
    libxaw3d \
    libxaw3d-dev \
    zlib \
    zlib-dev

CMD ["/bin/bash"]
