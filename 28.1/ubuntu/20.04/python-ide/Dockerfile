FROM josiah14/emacs:28.1-ubuntu20.04-dev
FROM ubuntu:20.04

ARG username
ARG uid
ARG fullname
ARG email

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64

COPY --from=0 /usr/local /usr/local

RUN apt-get -y update && apt-get install -y curl gnupg software-properties-common \
    && add-apt-repository ppa:git-core/ppa \
    && DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get update -y \
    && DEBIAN_FRONTEND=noninteractive TZ=US/Chicago apt-get install -y \
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
            # pyenv dependencies
            build-essential \
            libssl-dev \
            zlib1g-dev \
            libbz2-dev \
            libreadline-dev \
            libsqlite3-dev \
            wget \
            llvm \
            libncurses5-dev \
            libncursesw5-dev \
            xz-utils \
            tk-dev \
            libffi-dev \
            liblzma-dev \
            python \
            python-openssl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/$username/.emacs.d \
    && mkdir -p /home/$username/.doom.d \
    && mkdir -p /home/$username/.local/share/fonts \
    && useradd -u $uid $username \
    && chown -R $username:$username /home/$username

ADD https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer /home/$username/.local/bin/pyenv-installer.sh
RUN chown $username:$username /home/$username/.local/bin/pyenv-installer.sh \
    && chmod a+rx /home/$username/.local/bin/pyenv-installer.sh

USER $username

RUN cd /home/$username \
    && bash ./.local/bin/pyenv-installer.sh \
    && echo "export PYENV_ROOT=\"/home/$username/.pyenv\"" | tee -a ~/.shrc ~/.bashrc \
    && echo "export PATH=\"\$PYENV_ROOT/bin:$PATH\"" | tee -a ~/.shrc ~/.bashrc \
    && echo 'eval "$(pyenv init --path)"' | tee -a ~/.shrc ~/.bashrc \
    && echo 'eval "$(pyenv init -)"' | tee -a ~/.shrc ~/.bashrc \
    && echo 'eval "$(pyenv virtualenv-init -)"' | tee -a ~/.shrc ~/.bashrc \
    && /home/$username/.pyenv/bin/pyenv update \
    && curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py \
       | python - \
    && echo "export PATH=\"/home/$username/.poetry/bin:\$PATH\"" | tee -a ~/.shrc ~/.bashrc \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && git clone https://github.com/ryanoasis/nerd-fonts && cd nerd-fonts \
    && chmod +x install.sh && ./install.sh && cd .. && rm -rf nerd-fonts \
    && git clone --depth 1 https://github.com/hlissner/doom-emacs /home/$username/.emacs.d \
    && /home/$username/.emacs.d/bin/doom env help

COPY config.el /home/$username/.doom.d/config.el
COPY init.el /home/$username/.doom.d/init.el
COPY packages.el /home/$username/.doom.d/packages.el
COPY custom.el /home/$username/.doom.d/custom.el

RUN sed -i "s/<full-name>/\"$fullname\"/" /home/$username/.doom.d/config.el \
    && sed -i "s/<email-address>/\"$email\"/" /home/$username/.doom.d/config.el \
    && /home/$username/.emacs.d/bin/doom -y sync

CMD ["emacs"]
