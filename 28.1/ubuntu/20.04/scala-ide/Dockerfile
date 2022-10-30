FROM josiah14/emacs:28.1-ubuntu20.04-dev
FROM ubuntu:20.04

ARG username
ARG uid
ARG fullname
ARG email

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64
ADD https://git.io/coursier-cli /usr/bin/cs

COPY --from=0 /usr/local /usr/local

RUN apt-get -y update && apt-get install -y curl gnupg software-properties-common \
    && add-apt-repository ppa:git-core/ppa \
    && echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" \
        | tee /etc/apt/sources.list.d/sbt.list \
    && echo "deb https://repo.scala-sbt.org/scalasbt/debian /" \
        | tee /etc/apt/sources.list.d/sbt_old.list \
    && curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" \
        | apt-key add && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get install -y \
            ripgrep \
            git \
            fd-find \
            xclip \
            gpm \
            imagemagick \
            ispell \
            libacl1 \
            libasound2 \
            libcanberra-gtk3-module \
            libdbus-1-3 \
            libgccjit0 \
            libgccjit-10-dev \
            libgif7 \
            libgnutls30 \
            libgtk-3-0 \
            libjansson4 \
            libjpeg8 \
            liblcms2-2 \
            libm17n-0 \
            libpng16-16 \
            librsvg2-2 \
            libsm6 \
            libtiff5 \
            libx11-xcb1 \
            libxml2 \
            libxpm4 \
            openssh-client \
            texinfo \
            openjdk-11-jdk-headless \
            openjdk-11-jre-headless \
            sbt \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/$username/.emacs.d \
    && mkdir -p /home/$username/.doom.d \
    && mkdir -p /home/$username/.local/share/fonts \
    && mkdir -p /home/$username/.local/share/coursier/bin \
    && useradd -u $uid $username \
    && chown -R $username:$username /home/$username \
    && chmod a+rx /usr/bin/cs \
    && cs bootstrap \
        --java-opt -Xss4m \
        --java-opt -Xms100m \
        --java-opt -Dmetals.client=emacs \
        org.scalameta:metals_2.12:0.11.2 \
        -r bintray:scalacenter/releases \
        -r sonatype:snapshots \
        -o /usr/local/bin/metals-emacs -f -v -v -v \
    && cs install bloop --only-prebuilt=true --user-home /home/$username/ \
    && chown -R $username:$username /home/$username \
    && rm -f /usr/bin/cs

USER $username
ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64

RUN cd /home/$username \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && git clone https://github.com/ryanoasis/nerd-fonts && cd nerd-fonts \
    && chmod +x install.sh && ./install.sh && cd .. && rm -rf nerd-fonts \
    && export PATH="$PATH:/home/$username/.local/share/coursier/bin" \
    && echo PATH="$PATH:/home/$username/.local/share/coursier/bin" | tee -a ~/.bashrc ~/.shrc \
    && git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$username/.emacs.d

# This is done down here so that the Doom Emacs configuration can be more easily changed without
# the need to re-clone Doom and re-install the fonts, which takes a long time.
COPY config.el /home/$username/.doom.d/config.el
COPY init.el /home/$username/.doom.d/init.el
COPY packages.el /home/$username/.doom.d/packages.el
COPY custom.el /home/$username/.doom.d/custom.el

RUN sed -i "s/<full-name>/\"$fullname\"/" /home/$username/.doom.d/config.el \
    && sed -i "s/<email-address>/\"$email\"/" /home/$username/.doom.d/config.el \
    && /home/$username/.emacs.d/bin/doom env --help \
    && /home/$username/.emacs.d/bin/doom sync

CMD ["emacs"]
