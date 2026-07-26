ARG CHEZ_VERSION=10.4.1
ARG CHEZ_SHA256=2e74952db7bc177f0c3602e2217a341ba677d733eec4cd7726418c3a4e1ef308

# Reusable source image, same shape as josiah14/nix and josiah14/guix in
# systems-ide's own Dockerfile: nothing here is ever `docker run` directly,
# only `COPY --from=` by a consumer. Upstream ships no Linux binary at all
# (Windows-only prebuilt), and apt's chezscheme lags several minor versions
# behind (confirmed live: 10.0.0 on 26.04's own archive vs this 10.4.1) --
# so this builds from the official release tarball instead, matching this
# project's general bias against stale/absent apt packages (Racket/Nu/ruff/
# stylua/lua-language-server all take the same "pinned official artifact
# over apt" shape elsewhere in this repo).
FROM ubuntu:26.04 AS build
ARG CHEZ_VERSION
ARG CHEZ_SHA256
ARG DEBIAN_FRONTEND=noninteractive

# Single RUN, chained end to end -- keeps this build stage to one layer.
# libc6-dev isn't pulled in by gcc alone on a bare ubuntu:26.04 image
# (confirmed live: without it, gcc can't even find stdio.h) -- listed
# explicitly rather than reaching for the build-essential meta-package,
# which would also drag in g++/dpkg-dev that this build never uses.
# `strip` itself needs no separate package -- gcc already depends on
# binutils (confirmed live). The release tarball ships prebuilt "boot/pb"
# portable-bytecode boot files (confirmed directly from BUILDING), so
# `./configure && make && make install` is genuinely standalone here --
# no bootstrap chicken-and-egg problem requiring an existing Scheme,
# unlike what a from-scratch Chez build could otherwise be.
# `--disable-x11 --disable-curses`: both are terminal/windowing
# conveniences for driving Chez interactively at a raw shell prompt
# (curses-based line editing, an X11-backed editor feature); irrelevant
# here since Geiser talks to Chez over a plain subprocess pipe, not a
# real tty, so neither ever activates -- dropping both means this image
# needs no runtime shared libraries beyond glibc itself, and no
# libncurses-dev/libx11-dev at build time either.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gcc \
      libc6-dev \
      make \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/cisco/ChezScheme/releases/download/v${CHEZ_VERSION}/csv${CHEZ_VERSION}.tar.gz" -o /tmp/chez.tar.gz \
    && echo "${CHEZ_SHA256}  /tmp/chez.tar.gz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/chez.tar.gz \
    && cd "/tmp/csv${CHEZ_VERSION}" \
    && ./configure --installprefix=/opt/chez --disable-x11 --disable-curses \
    && make -j"$(nproc)" \
    && make install \
    && strip --strip-all /opt/chez/lib/csv${CHEZ_VERSION}/*/scheme /opt/chez/lib/csv${CHEZ_VERSION}/*/petite \
    && rm -rf /tmp/chez.tar.gz "/tmp/csv${CHEZ_VERSION}"

FROM ubuntu:26.04
COPY --from=build /opt/chez /opt/chez
