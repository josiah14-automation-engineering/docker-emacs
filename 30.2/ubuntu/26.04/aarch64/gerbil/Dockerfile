ARG GERBIL_VERSION=0.18.2
# Commit the v0.18.2 tag resolves to (confirmed live via `gh api
# repos/mighty-gerbils/gerbil/commits/v0.18.2`) -- recorded for
# traceability even though the actual checkout below is by tag name, not
# this SHA directly (a shallow clone by tag is what makes
# --shallow-submodules work; see the comment below).
ARG GERBIL_COMMIT=07c8481588a8b07dbf05832687817cd398902ac0

# Reusable source image, same shape as josiah14/chez and josiah14/gambit
# alongside it -- nothing here is ever `docker run` directly, only
# `COPY --from=` by a consumer.
#
# Reversed from an earlier version of this file that pulled prebuilt
# binaries out of the official gerbil/ubuntu image: that image's
# aarch64-capable tags were all built 2023-10-18 (confirmed live from
# the image's own file timestamps), three years stale relative to this
# v0.18.2 tag -- too old to accept just to avoid a source build,
# especially once the actual build turned out to need nothing exotic
# (see below). See DECISIONLOG.md for the full history of this reversal.
#
# Gerbil bundles its own pinned copy of Gambit as a git submodule since
# v0.18 (confirmed live from cons.io's own build docs), so this needs a
# real `git clone --recurse-submodules`, not a plain tarball fetch --
# GitHub's own tarball/zip archive endpoints do not include submodule
# content, only an empty mount-point directory for it. `--depth 1
# --shallow-submodules` keeps both the superproject and the bundled
# Gambit submodule shallow, since a full history clone of either isn't
# needed just to build.
FROM ubuntu:26.04 AS build
ARG GERBIL_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# Package list trimmed from upstream's own dist/packages.mk
# `ubuntu_packages` (confirmed directly from mighty-gerbils/gerbil's own
# dist/docker build recipe) -- dropped rsync/rubygems/texinfo, which
# that file only needs for its own fpm-based .deb/.rpm packaging
# pipeline, not for a plain `./configure && make && make install`.
# `--enable-poll` is upstream's own documented recommendation for
# Linux/BSD (a more scalable poll-based i/o scheduler). Single RUN,
# chained end to end -- keeps this build stage to one layer. `strip`
# needs no separate package -- gcc already depends on binutils.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      autoconf \
      bison \
      build-essential \
      ca-certificates \
      curl \
      gawk \
      git \
      libleveldb-dev \
      liblmdb-dev \
      libnss3-dev \
      libsqlite3-dev \
      libssl-dev \
      libxml2-dev \
      libyaml-dev \
      pkg-config \
      python3 \
      zlib1g-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && git clone --recurse-submodules --shallow-submodules --branch "v${GERBIL_VERSION}" --depth 1 \
         https://github.com/mighty-gerbils/gerbil.git /tmp/gerbil \
    && cd /tmp/gerbil \
    && ./configure --prefix=/opt/gerbil --enable-poll \
    && make -j"$(nproc)" \
    && make install \
    && strip --strip-all "$(readlink -f /opt/gerbil/bin/gerbil)" "$(readlink -f /opt/gerbil/bin/gsc)" \
    && rm -rf /tmp/gerbil

FROM ubuntu:26.04
COPY --from=build /opt/gerbil /opt/gerbil
