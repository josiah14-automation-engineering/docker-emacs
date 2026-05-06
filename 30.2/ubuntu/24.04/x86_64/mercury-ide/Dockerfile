FROM josiah14/emacs:30.2-skylake-ubuntu-24.04-dev AS emacs-build


# --- Mercury build stage ---
FROM ubuntu:24.04 AS mercury-build

ARG MERCURY_VERSION=22.01.8
ARG DEBIAN_FRONTEND=noninteractive

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean

RUN apt-get update -y && \
    apt-get install -y \
      ca-certificates \
      curl \
      gawk \
      build-essential \
      gcc \
      g++ \
      make \
      autoconf \
      automake \
      libtool \
      pkg-config \
      flex \
      bison \
      libffi-dev \
      libgmp-dev \
      libicu-dev \
      libreadline-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Build Mercury from source in two stages. Each grade is a distinct ABI selecting
# the GC strategy, parallelism model, threading model, and backend.
#
# make always builds the default grade automatically; --enable-libgrades adds
# additional grades on top of it. Both grades end up in the image:
#   asm_fast.gc.par.stseg          — default runtime grade, explicitly set via
#                                    --with-default-grade; without this flag
#                                    configure auto-selects the simpler asm_fast.gc
#                                    which lacks parallelism support
#   asm_fast.gc.par.stseg.debug    — enables mdb, Mercury's source-level debugger
# Note: asm_fast.gc.par.stseg.profdeep was dropped due to a bug in Mercury 22.01.8:
# the compiler's deep profiling instrumentation (ll_backend.prog_rep.goal_to_goal_rep/4)
# cannot handle parallel conjunctions (&), which the integer module uses. This is a
# Mercury compiler bug, not a build configuration or resource issue.
#
# Two-stage build: with no Mercury compiler available to bootstrap from, stage 1
# compiles mmc itself using the slower hlc.gc.pregen grade (portable C). Stage 2
# uses the just-installed mmc to recompile everything, producing a faster compiler
# built in the target grade. Between stages the source tree is reset by removing
# and re-extracting from the tarball — make realclean is documented as the correct
# approach but fails post-install because scripts/mmake is no longer in place.
#
# Note: Mercury uses PARALLEL=-jN rather than the standard make -jN flag.
# Note: the sha512 file is extracted with awk to isolate the hash field, making
# the check robust to both "hash-only" and "hash  filename" file formats.
# The build fails loudly at sha512sum if the tarball is corrupt or tampered with.
RUN curl -fsSL https://dl.mercurylang.org/release/mercury-srcdist-${MERCURY_VERSION}.tar.xz \
         -o mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && curl -fsSL https://dl.mercurylang.org/release/mercury-srcdist-${MERCURY_VERSION}.tar.xz.sha512 \
         -o mercury-srcdist-${MERCURY_VERSION}.tar.xz.sha512 \
    && echo "$(awk '{print $1}' mercury-srcdist-${MERCURY_VERSION}.tar.xz.sha512)  mercury-srcdist-${MERCURY_VERSION}.tar.xz" \
         | sha512sum -c - \
    && tar -xf mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && cd mercury-srcdist-${MERCURY_VERSION} \
    && ./configure \
         --prefix=/usr/local \
         --with-default-grade=asm_fast.gc.par.stseg \
         --enable-libgrades=asm_fast.gc.par.stseg.debug \
         CFLAGS="-O2 -march=skylake -mtune=skylake" \
    && make PARALLEL=-j$(nproc) \
    && make PARALLEL=-j$(nproc) install \
    && cd .. \
    && rm -rf mercury-srcdist-${MERCURY_VERSION} \
    && tar -xf mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && cd mercury-srcdist-${MERCURY_VERSION} \
    && ./configure \
         --prefix=/usr/local \
         --with-default-grade=asm_fast.gc.par.stseg \
         --enable-libgrades=asm_fast.gc.par.stseg.debug \
         CFLAGS="-O2 -march=skylake -mtune=skylake" \
    && make PARALLEL=-j$(nproc) \
    && make PARALLEL=-j$(nproc) install \
    && cd .. \
    && rm -rf mercury-srcdist-${MERCURY_VERSION} \
              mercury-srcdist-${MERCURY_VERSION}.tar.xz \
              mercury-srcdist-${MERCURY_VERSION}.tar.xz.sha512


# --- Final image ---
FROM ubuntu:24.04

ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG FULLNAME
ARG EMAIL
ARG DOOM_REPO=https://github.com/doomemacs/doomemacs
ARG DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NO_AT_BRIDGE=1
ENV DOOMDIR=/home/${USERNAME}/.config/doom
ENV PATH="/home/${USERNAME}/.config/emacs/bin:/home/${USERNAME}/.local/bin:${PATH}"

COPY --from=emacs-build /usr/local /usr/local
COPY --from=mercury-build /usr/local /usr/local

RUN printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' \
      > /etc/apt/apt.conf.d/99lean

RUN apt-get update -y && \
    apt-get install -y \
      ca-certificates \
      curl \
      gawk \
      git \
      gnupg \
      ripgrep \
      fd-find \
      unzip \
      bash \
      findutils \
      coreutils \
      xz-utils \
      tar \
      sudo \
      locales \
      libgccjit-13-dev \
      gdb \
      imagemagick \
      iputils-ping \
      aspell \
      libacl1 \
      libasound2t64 \
      alsa-base \
      bzip2 \
      libcanberra-gtk3-0 \
      dbus \
      x11-utils \
      dbus-x11 \
      libgif7 \
      libgnutls30 \
      libgpm2 \
      gpm \
      libglib2.0-0t64 \
      libjansson4 \
      libjpeg-turbo8 \
      liblcms2-2 \
      liblockfile-bin \
      libtiff6 \
      libgtk-3-0 \
      libm17n-0 \
      libncurses6 \
      libncursesw6 \
      libtinfo6 \
      libsm6 \
      libwebpdemux2 \
      libwebp7 \
      libwebpdecoder3 \
      libtree-sitter0 \
      libxext6 \
      librsvg2-2 \
      libxml2 \
      libxrender1 \
      openssh-client \
      texinfo \
      wget \
      libxaw7 \
      libxcb-util1 \
      zlib1g \
      fonts-dejavu-core \
      adwaita-icon-theme \
      fonts-firacode \
      fonts-jetbrains-mono \
      fontconfig \
      vim \
      libgmp10 \
      libffi8 \
      libicu74 \
      libreadline8 \
    && mkdir -p /etc/apt/keyrings \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


# We don't need the default ubuntu user, and that user's uid is likely to conflict
# with the base system's uid, so we delete that user and any files and directories
# associated. Then, create the user and directory that matches the host system's
# current user during the build of the container.
RUN userdel ubuntu || true \
    && groupadd -g ${USER_GID} ${USERNAME} \
    && mkdir -p /home/${USERNAME}/.config/emacs \
    && mkdir -p /home/${USERNAME}/.local/share/fonts \
    && useradd -u ${USER_UID} -g ${USER_GID} ${USERNAME} \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

RUN cd /home/${USERNAME} \
    && git clone https://github.com/powerline/fonts.git \
    && cd fonts \
    && git checkout a029626780dd4af32f15a3e708a5b00528c22f1d \
    && chmod +x install.sh && ./install.sh \
    && cd .. && rm -rf ./fonts \
    && mkdir -p /home/${USERNAME}/.local/share/fonts/truetype/source-code-pro \
    && wget -q https://github.com/adobe-fonts/source-code-pro/archive/refs/tags/variable-fonts.tar.gz \
         -O /tmp/source-code-pro.tar.gz \
    && echo "2c55c413bab7d51f252659c63ba65624653dd03c1c64f0c16ece6973e5ae9a821e3675e04bbace263ceeaf71875538197071018761e00351359c876d7ad89fd6  /tmp/source-code-pro.tar.gz" \
         | sha512sum -c - \
    && tar xz --strip-components=1 -C ~/.local/share/fonts/truetype/source-code-pro \
         -f /tmp/source-code-pro.tar.gz \
    && rm /tmp/source-code-pro.tar.gz \
    && fc-cache -fv

RUN git clone "${DOOM_REPO}" /home/${USERNAME}/.config/emacs \
    && cd /home/${USERNAME}/.config/emacs && git fetch --all && git reset --hard "${DOOM_COMMIT}" \
    && /home/${USERNAME}/.config/emacs/bin/doom install -! --aot \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

# Config and lockfile are copied after the expensive doom install + sync steps so
# that changes to these files only invalidate the last two layers.
COPY --chown=${USERNAME}:${USERNAME} config.el   /home/${USERNAME}/.config/doom/config.el
COPY --chown=${USERNAME}:${USERNAME} init.el     /home/${USERNAME}/.config/doom/init.el
COPY --chown=${USERNAME}:${USERNAME} packages.el /home/${USERNAME}/.config/doom/packages.el
COPY --chown=${USERNAME}:${USERNAME} mercury.el      /home/${USERNAME}/.config/doom/mercury.el
COPY --chown=${USERNAME}:${USERNAME} keybindings.el /home/${USERNAME}/.config/doom/keybindings.el
COPY --chown=${USERNAME}:${USERNAME} straight-versions.el \
     /home/${USERNAME}/.config/emacs/.local/straight/versions/default.el

RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/${USERNAME}/.config/emacs/bin/doom env \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

CMD ["emacs"]
