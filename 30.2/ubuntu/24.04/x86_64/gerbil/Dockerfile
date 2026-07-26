ARG GERBIL_VERSION=0.18.2
# Commit the v0.18.2 tag resolves to (confirmed live via `gh api
# repos/mighty-gerbils/gerbil/commits/v0.18.2`) -- recorded for
# traceability even though the actual checkout below is by tag name, not
# this SHA directly (a shallow clone by tag is what makes
# --shallow-submodules work; see the comment below).
ARG GERBIL_COMMIT=07c8481588a8b07dbf05832687817cd398902ac0

# Mirror of the aarch64 tree's own gerbil/Dockerfile -- source-mirror
# only, not independently built/tested on x86_64 this session. Same
# reasoning as that file (reversed from an initial prebuilt-image
# approach once the pulled build turned out to be three years stale --
# see DECISIONLOG.md for the full history): Gerbil bundles its own
# pinned Gambit as a git submodule since v0.18, so this needs a real
# `git clone --recurse-submodules`, not a plain tarball fetch. The
# source and ./configure both work identically across architectures --
# only the base image tag changes, to match this tree's own Ubuntu
# 24.04.
FROM ubuntu:24.04 AS build
ARG GERBIL_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# Package list trimmed from upstream's own dist/packages.mk
# `ubuntu_packages` -- see the aarch64 tree's own gerbil/Dockerfile for
# why rsync/rubygems/texinfo were dropped. Single RUN, chained end to
# end -- keeps this build stage to one layer. `strip` needs no separate
# package -- gcc already depends on binutils.
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

FROM ubuntu:24.04
COPY --from=build /opt/gerbil /opt/gerbil
