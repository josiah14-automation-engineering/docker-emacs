FROM alpine:edge

# autoconf, automake, and libtool make up Ubuntu autotools
# alsa-lib replaces libasound2
# tiff replaces libotf
# gawk replaces awk because regular awk breaks the gcc compilation
RUN apk add autoconf \
    automake \
    libtool \
    build-base \
    alpine-sdk \
    curl \
    dpkg \
    dpkg-dev \
    gawk \
    git \
    gnupg \
    libgccjit \
    libgccjit-dev \
    gcc \
    imagemagick \
    imagemagick-dev \
    iputils-ping \
    aspell \
    aspell-dev \
    libacl \
    acl-dev \
    alsa-lib \
    alsa-lib-dev \
    libcanberra-gtk3 \
    libcanberra-dev \
    dbus-libs \
    dbus-dev \
    giflib \
    giflib-dev \
    gnutls \
    gnutls-dev \
    gpm \
    gpm-libs \
    gpm-dev \
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
    zlib-dev \
 && rm -rf /var/cache/apk/*

RUN git clone --depth 1 --branch emacs-29.2 git://git.savannah.gnu.org/emacs.git /opt/emacs && \
    cd /opt/emacs && \
    ./autogen.sh && \
    ./configure --without-pop --with-native-compilation --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
                --with-modules --with-gnutls --with-json --with-rsvg --with-xml2 --with-wide-int \
                --with-cairo --with-harfbuzz --with-png --with-tiff --with-gif \
                CFLAGS="-O3 -pipe -flto -freciprocal-math -fassociative-math -frename-registers -funroll-loops -mtune=cortex-a72 -mcpu=cortex-a72+crc -floop-parallelize-all -ftree-parallelize-loops=4" && \
                LDFLAGS="-Wl,-O1 -Wl,--as-needed -flto" && \
    make -j"$(nproc)" && \
    make install && cd .. && rm -rf ./emacs

RUN mkdir -p /root/.emacs.d/elpa/gnupg && \
    chmod 700 /root/.emacs.d/elpa/gnupg && \
    for i in {1..3}; do \
      gpg --keyserver keys.gnupg.net \
          --homedir /root/.emacs.d/elpa/gnupg \
          --recv-keys 066DAFCB81E42C40 \
      && break || sleep 15; \
    done

CMD ["emacs"]
