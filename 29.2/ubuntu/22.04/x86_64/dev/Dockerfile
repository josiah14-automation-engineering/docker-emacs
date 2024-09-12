FROM ubuntu:22.04

RUN DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get install -y \
            libwebp-dev \
            libtree-sitter-dev \
            libsqlite3-dev \
            libseccomp-dev \
            libxft-dev \
            libx11-dev \
            libx11-xcb-dev \
            libxcb1-dev \
            libxcb-shape0-dev \
            valgrind \
            libpthread-stubs0-dev \
            gawk \
            libtool \
            autoconf \
            automake \
            autotools-dev \
            build-essential \
            curl \
            dpkg-dev \
            git \
            gnupg \
            libgccjit0 \
            libgccjit-11-dev \
            gcc-10 \
            imagemagick \
            libmagickwand-dev \
            libmagickcore-dev \
            iputils-ping \
            ispell \
            libacl1-dev \
            libasound2-dev \
            libcanberra-gtk3-module \
            libdbus-1-dev \
            libgif-dev \
            libgnutls28-dev \
            libgpm-dev \
            libgtk-3-dev \
            libwebkit2gtk-4.1-dev \
            libjansson-dev \
            libjpeg-dev \
            liblcms2-dev \
            liblockfile-dev \
            libm17n-dev \
            libmagick++-6.q16-dev \
            libncurses5-dev \
            libotf-dev \
            libpng-dev \
            librsvg2-dev \
            libselinux1-dev \
            libtiff-dev \
            libxaw7-dev \
            libxml2-dev \
            openssh-client \
            texinfo \
            wget \
            xaw3dg-dev \
            zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch emacs-29.2 git://git.savannah.gnu.org/emacs.git /opt/emacs && \
    cd /opt/emacs && \
    ./autogen.sh && \
    ./configure --without-pop --with-native-compilation --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
                --with-modules --with-gnutls --with-json --with-rsvg --with-xml2 --with-wide-int \
                --with-cairo --with-harfbuzz --with-png --with-tiff --with-gif \
                CFLAGS="-O3 -pipe -flto -freciprocal-math -frename-registers -funroll-loops -mtune=skylake -march=skylake -floop-parallelize-all -ftree-parallelize-loops=4" && \
                LDFLAGS="-Wl,-O1 -Wl,--as-needed -flto" && \
    make -j"$(( $(nproc) + 4 ))" V=1 && \
    make install

RUN mkdir -p /root/.emacs.d/elpa/gnupg && \
    chmod 700 /root/.emacs.d/elpa/gnupg && \
    for i in {1..3}; do \
      gpg --keyserver keyserver.ubuntu.com \
          --homedir /root/.emacs.d/elpa/gnupg \
          --recv-keys 066DAFCB81E42C40 \
      && break || sleep 15; \
    done

CMD ["emacs"]
