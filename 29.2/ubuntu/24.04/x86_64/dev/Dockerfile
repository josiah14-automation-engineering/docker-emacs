FROM ubuntu:24.04

RUN DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-cache policy \
            autoconf \
            automake \
            autotools-dev \
            build-essential \
            ca-certificates \
            curl \
            dpkg-dev \
            gawk \
            gcc \
            git \
            gnupg \
            imagemagick \
            iputils-ping \
            ispell \
            libacl1-dev \
            libasound2-dev \
            libcanberra-gtk3-module \
            libdbus-1-dev \
            libgccjit0 \
            libgccjit-13-dev \
            libgif-dev \
            libgnutls28-dev \
            libgpm-dev \
            libgtk-3-dev \
            libjansson-dev \
            libjpeg-dev \
            liblcms2-dev \
            liblockfile-dev \
            libm17n-dev \
            libmagick++-6.q16-dev \
            libmagickcore-dev \
            libmagickwand-dev \
            libncurses-dev \
            libotf-dev \
            libpng-dev \
            librsvg2-dev \
            libseccomp-dev \
            libselinux1-dev \
            libsqlite3-dev \
            libtiff-dev \
            libtool \
            libtree-sitter-dev \
            libwebp-dev \
            libwebkit2gtk-4.1-dev \
            libx11-dev \
            libx11-xcb-dev \
            libxaw7-dev \
            libxcb-shape0-dev \
            libxcb1-dev \
            libxft-dev \
            libxml2-dev \
            openssh-client \
            sudo \
            texinfo \
            valgrind \
            wget \
            xaw3dg-dev \
            zlib1g-dev && \
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
            libgccjit-13-dev \
            gcc \
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

# RUN git clone --depth 1 --branch "${EMACS_VERSION}" https://git.savannah.gnu.org/git/emacs.git /opt/emacs && \
RUN git clone --depth 1 --branch emacs-29.2 git://git.savannah.gnu.org/emacs.git /opt/emacs \
 && cd /opt/emacs \
 && ./autogen.sh \
 && ./configure --without-pop --with-native-compilation --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
                --with-modules --with-gnutls --with-json --with-rsvg --with-xml2 --with-wide-int --with-tree-sitter \
                --with-cairo --with-harfbuzz --with-png --with-tiff --with-gif --enable-link-time-optimization \
                CFLAGS="-O2 -pipe -mtune=skylake -march=skylake" \
                LDFLAGS="-Wl,-O1 -Wl,--as-needed" \
 && make -j"$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" V=1 \
 && make install

RUN mkdir -p "/root/.emacs.d/elpa/gnupg" && \
    chmod 700 "/root/.emacs.d/elpa/gnupg" && \
    for i in {1..3}; do \
      gpg --keyserver keyserver.ubuntu.com \
          --homedir /root/.emacs.d/elpa/gnupg \
          --recv-keys 066DAFCB81E42C40 \
      && break || sleep 15; \
    done

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

# delete the default ubuntu user and group, then create the runtime user
# which matches the host system's user for running emacs GUI without elevated
# privileges
RUN set -eux \
 && mkdir -p "/etc/sudoers.d" \
 && if id -u ubuntu >/dev/null 2>&1; then \
      userdel --remove ubuntu; \
    fi; \
    if getent group ubuntu >/dev/null; then \
      groupdel ubuntu; \
    fi \
 && if getent group "${USER_GID}" >/dev/null; then \
      EXISTING_GROUP="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
      EXISTING_GROUP="${USERNAME}"; \
    fi \
 && if id -u "${USER_UID}" >/dev/null 2>&1; then \
      echo "User with UID ${USER_UID} already exists"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}"; \
    fi \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}"

USER ${USERNAME}

RUN mkdir -p "/home/${USERNAME}/.emacs.d/elpa/gnupg" \
 && chmod 700 "/home/${USERNAME}/.emacs.d/elpa/gnupg" \
 && for i in {1..3}; do \
      gpg --keyserver keyserver.ubuntu.com \
          --homedir "/home/${USERNAME}/.emacs.d/elpa/gnupg" \
          --recv-keys 066DAFCB81E42C40 \
      && break || sleep 15; \
    done

CMD ["emacs"]
