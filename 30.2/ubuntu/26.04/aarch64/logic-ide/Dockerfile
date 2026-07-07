FROM josiah14/emacs:30.2-m2-ubuntu-26.04-dev AS emacs-build

ARG MCPU=apple-m2+crc+aes+sha3+fp16


# --- Mercury build stage ---
FROM ubuntu:26.04 AS mercury-build

ARG MCPU
ARG MERCURY_VERSION=22.01.8
ARG MERCURY_SHA512=61c1f34f48bf2bfc045ff5b78f7c2803fed99430e1a5ccb341f71f34c71f6fdcb2d3eb25c8c4cee04786d1b2b1ab203cc4eaefea67e17643e65dbf048a0e0ea4
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
      libncurses-dev \
      texinfo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Build Mercury from source in two stages. Each grade is a distinct ABI selecting
# the GC strategy, parallelism model, threading model, and backend.
#
# Grade set matches ~/Development/personal/mise's nixpkgs mercury derivation
# (languages/mercury/compilers/22.01.8.nix) exactly, so code compiled here and code
# compiled in a mise/nix-managed shell land on the same set of ABIs:
#   asm_fast.gc.stseg          — default grade (--with-default-grade); sequential,
#                                Boehm GC, segmented stack
#   asm_fast.par.gc.stseg      — parallel variant of the default
#   asm_fast.gc.debug.stseg    — enables mdb, Mercury's source-level debugger
#   asm_fast.gc.prof.stseg     — flat profiling (mprof)
#   asm_fast.gc.profdeep.stseg — deep call-graph profiling (mdprof)
#   asm_fast.gc.tr             — trailing, for solver types / CLP
# make always builds the default grade automatically; --enable-libgrades adds the
# other five on top of it.
#
# This is a change from the x86_64/24.04 image, which defaults to the *parallel*
# grade (asm_fast.gc.par.stseg) and only builds a debug grade — deep profiling was
# dropped there after asm_fast.gc.par.stseg.profdeep hit a Mercury 22.01.8 compiler
# bug: the deep-profiling instrumentation (ll_backend.prog_rep.goal_to_goal_rep/4)
# cannot handle the parallel conjunctions (&) used by the `integer` stdlib module.
# That bug is specific to the *parallel* grade component. asm_fast.gc.profdeep.stseg
# (no `.par`) does not carry it, and building it here (see BUILDLOG.md for the
# verified result) is expected to succeed where the x86_64 image's grade did not.
# Matching mise's default grade (rather than keeping x86_64's parallel default)
# also means flycheck-mercury's bare `mmc` invocation (no `--grade` flag; see
# mercury.el) resolves to the same default grade a project built via mise/nix
# would use.
#
# libncurses-dev (readline+ncurses for mdb) and texinfo (makeinfo, for mdb/mdprof
# help text — without it configure warns "missing `makeinfo' or `info'" and ships
# without embedded help) are additional build deps beyond the x86_64/24.04 list,
# needed for this wider grade set; mise's derivation depends on pkgs.readline and
# pkgs.ncurses for the same reason.
#
# --enable-deep-profiler installs the mdprof_cgi web viewer; its target directory
# must exist before configure runs (mise's nix derivation does the same mkdir in
# its preConfigure hook) or configure fails with "does not exist".
#
# GCC 15 (Ubuntu 26.04's default gcc) build failure in Mercury's own runtime:
# mercury_wrapper.c/mercury_trace_base.c assign the result of strrchr() on a
# `const char *` to a plain `char *`, which GCC's const-correct builtin strrchr
# prototype now flags as -Wdiscarded-qualifiers. This is a GCC-version issue,
# not architecture-specific — it reproduces because 26.04 defaults to gcc-15 vs.
# 24.04's gcc-13, not because of aarch64 vs. x86_64. Downgrading the compiler to
# dodge it was tried and rejected: gcc-13 doesn't recognize `apple-m2` as a valid
# -mcpu value at all (Apple Silicon -mcpu support is newer-GCC-only), so it can't
# be used to build with M2 tuning regardless.
#
# A `CFLAGS=... -Wno-error=discarded-qualifiers` was tried first and does NOT
# work: this specific failure is in the `runtime/` directory's bootstrap compile
# (both `mercury_wrapper.o`/`mercury_trace_base.o` build before mmc exists), and
# `runtime/Mmakefile` passes its own hardcoded `MGNUCFLAGS` (`--c-debug --no-ansi`)
# to `scripts/mgnuc`, not the user's `CFLAGS` — confirmed by the actual failing
# invocation logged during a build attempt: `../scripts/mgnuc --grade
# hlc.gc.pregen --c-debug --no-ansi -- -c mercury_trace_base.c -o
# mercury_trace_base.o`, with no CFLAGS-derived flags present at all. The
# `Mmake.vars.in`-appends-$(ALL_CFLAGS)-after-`--` mechanism does apply to other
# Mercury build targets (grade-specific library/compiler compiles), just not to
# this one — Mercury's build system doesn't thread user CFLAGS through uniformly
# across every Mmakefile in the tree.
#
# The fix instead patches the *generated* scripts/mgnuc (produced fresh by each
# ./configure call, hence reapplied after both configure invocations below):
# mgnuc's final gcc invocation is `${CC} ${ALL_CC_OPTS} "$@" ${OVERRIDE_OPTS}
# ${ALL_LOCAL_C_INCL_DIRS}` — OVERRIDE_OPTS is the last thing appended, after
# both `"$@"` (the per-file compile args) and mgnuc's own hardcoded -Werror for
# hlc.* grades, and it's honored by every compile mgnuc performs regardless of
# which Mmakefile invoked it or what flags that Mmakefile threads through. The
# sed inserts an assignment appending -Wno-error=discarded-qualifiers to
# OVERRIDE_OPTS immediately before the one line in mgnuc that consumes it (a
# unique anchor — an earlier, unrelated `case $# in` block earlier in the file
# handles default-grade argument injection and must NOT be used as the anchor).
# GCC processes -W flags in order, so appearing last means this correctly
# exempts just this one diagnostic back to warning severity without needing to
# touch -Werror as a whole. Empirically verified in an isolated container
# against both previously-failing files before committing to a full rebuild —
# see BUILDLOG.md for the investigation, including why the more obvious
# `-Wno-discarded-qualifiers` (suppressing the diagnostic itself rather than
# just its error promotion) was tried and also did not reach this compile.
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
# Note: six grades take considerably longer to build than the x86_64 image's two —
# Mercury's own configure estimates 1-3 hours per stage for this grade count.
RUN curl -fsSL https://dl.mercurylang.org/release/mercury-srcdist-${MERCURY_VERSION}.tar.xz \
         -o mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && echo "${MERCURY_SHA512}  mercury-srcdist-${MERCURY_VERSION}.tar.xz" \
         | sha512sum -c - \
    && tar -xf mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && cd mercury-srcdist-${MERCURY_VERSION} \
    && mkdir -p /usr/local/lib/mercury/cgi-bin \
    && ./configure \
         --prefix=/usr/local \
         --with-default-grade=asm_fast.gc.stseg \
         --enable-libgrades=asm_fast.par.gc.stseg,asm_fast.gc.debug.stseg,asm_fast.gc.prof.stseg,asm_fast.gc.profdeep.stseg,asm_fast.gc.tr \
         --enable-deep-profiler=/usr/local/lib/mercury/cgi-bin \
         CFLAGS="-O2 -mcpu=${MCPU}" \
    && sed -i '/set ${CC} ${ALL_CC_OPTS} "$@" ${OVERRIDE_OPTS} ${ALL_LOCAL_C_INCL_DIRS}/i\OVERRIDE_OPTS="${OVERRIDE_OPTS} -Wno-error=discarded-qualifiers"' scripts/mgnuc \
    && make PARALLEL=-j$(nproc) \
    && make PARALLEL=-j$(nproc) install \
    && cd .. \
    && rm -rf mercury-srcdist-${MERCURY_VERSION} \
    && tar -xf mercury-srcdist-${MERCURY_VERSION}.tar.xz \
    && cd mercury-srcdist-${MERCURY_VERSION} \
    && mkdir -p /usr/local/lib/mercury/cgi-bin \
    && ./configure \
         --prefix=/usr/local \
         --with-default-grade=asm_fast.gc.stseg \
         --enable-libgrades=asm_fast.par.gc.stseg,asm_fast.gc.debug.stseg,asm_fast.gc.prof.stseg,asm_fast.gc.profdeep.stseg,asm_fast.gc.tr \
         --enable-deep-profiler=/usr/local/lib/mercury/cgi-bin \
         CFLAGS="-O2 -mcpu=${MCPU}" \
    && sed -i '/set ${CC} ${ALL_CC_OPTS} "$@" ${OVERRIDE_OPTS} ${ALL_LOCAL_C_INCL_DIRS}/i\OVERRIDE_OPTS="${OVERRIDE_OPTS} -Wno-error=discarded-qualifiers"' scripts/mgnuc \
    && make PARALLEL=-j$(nproc) \
    && make PARALLEL=-j$(nproc) install \
    && cd .. \
    && rm -rf mercury-srcdist-${MERCURY_VERSION} \
              mercury-srcdist-${MERCURY_VERSION}.tar.xz \
              mercury-srcdist-${MERCURY_VERSION}.tar.xz.sha512


FROM josiah14/nix:2.34.7-ubuntu-26.04 AS nix-source

# --- Final image ---
FROM ubuntu:26.04

ARG USERNAME
ARG USER_UID
ARG USER_GID
ARG FULLNAME
ARG EMAIL
ARG DOOM_REPO=https://github.com/doomemacs/doomemacs
ARG DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57
ARG NERD_ICONS_COMMIT=1db0b0b9203cf293b38ac278273efcfc3581a05f
ARG NFM_SHA256=f0f624d9b474bea1662cf7e862d44aebe1ae1f6c7f9cb7a0ca5d0e5ac9561c60
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

# Package renames vs. the ubuntu-24.04/x86_64 image, verified against ubuntu:26.04
# arm64 repos: libgccjit-13-dev -> libgccjit-15-dev (must match the gcc 15 the
# emacs-build/mercury-build stages actually compiled against — the -13-dev package
# still resolves on 26.04 but is the wrong ABI, not just a naming change);
# libgnutls30 -> libgnutls30t64; libgtk-3-0 -> libgtk-3-0t64;
# libtree-sitter0 -> libtree-sitter0.25; libxml2 -> libxml2-16;
# libicu74 -> libicu78; libreadline8 -> libreadline8t64.
#
# swi-prolog-nox added for Prolog support (this image's new "logic" half
# alongside Mercury): verified on ubuntu:26.04 arm64 (universe, 9.2.9+dfsg,
# well above the sweeprolog.el package's documented >=8.5.18 requirement).
# Pulls in swi-prolog-core-packages as a transitive dependency, which is what
# actually matters here — it ships a *prebuilt* sweep-module.so plus
# sweep_link.pl (confirmed present at
# /usr/lib/swi-prolog/lib/aarch64-linux/sweep-module.so and
# /usr/lib/swi-prolog/library/ext/sweep/sweep_link.pl after just installing
# swi-prolog-nox, no core-packages listed explicitly). That means no cmake/
# gcc/pkg-config needs to land in this final image at all: the sweeprolog
# Elisp package's `sweeprolog--ensure-module' only searches Prolog's own
# foreign-library search path for an existing module (see
# packages-sweep/sweep_link.pl on GitHub) — it never compiles anything
# itself. Building the module from source would additionally require
# SWI-Prolog's full superbuild (packages-sweep's CMakeLists.txt includes
# "../cmake/PrologPackage.cmake", which only exists inside the complete
# swipl-devel checkout, not a standalone clone of the sweep package repo) —
# moot here since the distro build already provides the binary.
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
      libgccjit-15-dev \
      gdb \
      imagemagick \
      iputils-ping \
      aspell \
      swi-prolog-nox \
      libacl1 \
      libasound2t64 \
      alsa-base \
      bzip2 \
      libcanberra-gtk3-0 \
      dbus \
      x11-utils \
      dbus-x11 \
      libgif7 \
      libgnutls30t64 \
      libgpm2 \
      gpm \
      libglib2.0-0t64 \
      libjansson4 \
      libjpeg-turbo8 \
      liblcms2-2 \
      liblockfile-bin \
      libtiff6 \
      libgtk-3-0t64 \
      libm17n-0 \
      libncurses6 \
      libncursesw6 \
      libtinfo6 \
      libsm6 \
      libwebpdemux2 \
      libwebp7 \
      libwebpdecoder3 \
      libtree-sitter0.25 \
      libxext6 \
      librsvg2-2 \
      libxml2-16 \
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
      libicu78 \
      libreadline8t64 \
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

COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /nix /nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.local/state/nix /home/${USERNAME}/.local/state/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/nix /home/${USERNAME}/.config/nix
COPY --from=nix-source --chown=${USERNAME}:${USERNAME} /home/${USERNAME}/.config/direnv /home/${USERNAME}/.config/direnv

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

# The nix-source image's installer creates ~/.nix-profile as a symlink into
# ~/.local/state/nix/profiles/, but that symlink itself lives outside the four
# paths COPYed above, so it doesn't survive into this image. PATH (above) and
# ~/.config/direnv/direnvrc (source $HOME/.nix-profile/share/nix-direnv/direnvrc)
# both assume it exists, so recreate it pointing at the profile dir we did copy.
RUN ln -sf "/home/${USERNAME}/.local/state/nix/profiles/profile" "/home/${USERNAME}/.nix-profile" \
    && cd /home/${USERNAME} \
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
    && curl -fsSL "https://raw.githubusercontent.com/rainstormstudio/nerd-icons.el/${NERD_ICONS_COMMIT}/fonts/NFM.ttf" \
         -o /home/${USERNAME}/.local/share/fonts/NFM.ttf \
    && echo "${NFM_SHA256}  /home/${USERNAME}/.local/share/fonts/NFM.ttf" | sha256sum -c - \
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
COPY --chown=${USERNAME}:${USERNAME} prolog.el      /home/${USERNAME}/.config/doom/prolog.el
COPY --chown=${USERNAME}:${USERNAME} mercury-keybindings.el /home/${USERNAME}/.config/doom/mercury-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} prolog-keybindings.el /home/${USERNAME}/.config/doom/prolog-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} nix-keybindings.el /home/${USERNAME}/.config/doom/nix-keybindings.el
COPY --chown=${USERNAME}:${USERNAME} straight-versions.el \
     /home/${USERNAME}/.config/emacs/.local/straight/versions/default.el

RUN sed -i "s/<full-name>/\"${FULLNAME}\"/" /home/${USERNAME}/.config/doom/config.el \
    && sed -i "s/<email-address>/\"${EMAIL}\"/" /home/${USERNAME}/.config/doom/config.el \
    && git config --global url."http://git.savannah.gnu.org/git/".insteadOf "https://git.savannah.gnu.org/git/" \
    && ulimit -n 262144 \
    && /home/${USERNAME}/.config/emacs/bin/doom env \
    && /home/${USERNAME}/.config/emacs/bin/doom sync -! -u -j "$(( $(nproc) > 2 ? $(nproc) - 1 : 1 ))" --aot --gc

CMD ["emacs"]
