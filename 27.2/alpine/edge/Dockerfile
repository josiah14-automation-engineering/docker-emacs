FROM alpine:edge

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk
ENV COURSIER_USER root
ENV COURSIER_USER_HOME /root
ENV COURSIER_CACHE /cousier-cache

ADD https://git.io/coursier-cli /usr/bin/cs

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        alsa-lib \
        aspell \
        aspell-en \
        curl \
        xclip \
        grep \
        ripgrep \
        fd \
        coreutils \
        git \
        the_silver_searcher \
        openjdk11 \
        desktop-file-utils \
        dconf \
        dbus-x11 \
        fontconfig \
        nerd-fonts \
        gtk+3.0 \
        libcanberra-gtk3 \
        giflib \
        gnupg \
        jansson \
        lcms2 \
        librsvg \
        libxpm \
        openssh-client \
        tiff \
        emacs-x11 \
        sbt \
        && rm -rf /var/cache/* /tmp/* /var/log/* ~/.cache \
        && mkdir -p /var/cache/apk \
        && chmod a+rx /usr/bin/cs \
        && mkdir -p ${COURSIER_CACHE} \
        && chown -R ${COURSIER_USER}:${COURSIER_USER} ${COURSIER_USER_HOME} ${COURSIER_CACHE} \
        && cs bootstrap \
                --java-opt -Xss4m \
                --java-opt -Xms100m \
                --java-opt -Dmetals.client=emacs \
                org.scalameta:metals_2.12:0.10.1 \
                -r bintray:scalacenter/releases \
                -r sonatype:snapshots \
                -o /usr/local/bin/metals-emacs -f -v -v -v \
        && cs install bloop --only-prebuilt=true \
        && export PATH="$PATH:/root/.local/share/coursier/bin" \
        && echo PATH="$PATH:/root/.local/share/coursier/bin" >> ~/.shrc \
        && sbt sbtVersion \
        && git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d \
        && /root/.emacs.d/bin/doom -y install

COPY config.el /root/.doom.d/config.el
COPY init.el /root/.doom.d/init.el
COPY packages.el /root/.doom.d/packages.el
COPY custom.el /root/.doom.d/custom.el

RUN /root/.emacs.d/bin/doom -y sync && /root/.emacs.d/bin/doom -y build

CMD ["emacs"]
