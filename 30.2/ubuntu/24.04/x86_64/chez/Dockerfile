ARG CHEZ_VERSION=10.4.1
ARG CHEZ_SHA256=2e74952db7bc177f0c3602e2217a341ba677d733eec4cd7726418c3a4e1ef308

# Mirror of the aarch64 tree's own chez/Dockerfile -- source-mirror only,
# not independently built/tested on x86_64 this session (see that file
# for the full reasoning: no Linux binary exists upstream at all, apt
# lags several minor versions behind, and the release tarball ships boot
# files so this needs no bootstrap Scheme). The source tarball and
# ./configure both work identically across architectures -- only the
# base image tag changes, to match this tree's own Ubuntu 24.04.
FROM ubuntu:24.04 AS build
ARG CHEZ_VERSION
ARG CHEZ_SHA256
ARG DEBIAN_FRONTEND=noninteractive

# Single RUN, chained end to end -- keeps this build stage to one layer.
# libc6-dev isn't pulled in by gcc alone (confirmed live on the aarch64
# tree's own ubuntu:26.04 base; not independently re-verified against
# 24.04 here, but the same gcc/libc6-dev package relationship holds).
# `strip` itself needs no separate package -- gcc already depends on
# binutils. `--disable-x11 --disable-curses`: see the aarch64 tree's own
# chez/Dockerfile for why -- Geiser talks to Chez over a plain subprocess
# pipe, so neither ever activates, and dropping both means no runtime
# shared libraries beyond glibc itself.
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

FROM ubuntu:24.04
COPY --from=build /opt/chez /opt/chez
