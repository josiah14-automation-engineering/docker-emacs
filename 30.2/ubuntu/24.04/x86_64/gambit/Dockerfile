ARG GAMBIT_VERSION=4.9.7
ARG GAMBIT_SHA256=0da7c9772a2186dab1fba6bf6c777afe7424f40beacadf1b117d5cc825fe2db3

# Mirror of the aarch64 tree's own gambit/Dockerfile -- source-mirror
# only, not independently built/tested on x86_64 this session (see that
# file for the full reasoning: apt's gambc is four releases behind, and
# the tagged source archive ships pregenerated .c files so this needs no
# bootstrap Scheme). The source archive and ./configure both work
# identically across architectures -- only the base image tag changes,
# to match this tree's own Ubuntu 24.04.
FROM ubuntu:24.04 AS build
ARG GAMBIT_VERSION
ARG GAMBIT_SHA256
ARG DEBIAN_FRONTEND=noninteractive

# Single RUN, chained end to end -- keeps this build stage to one layer.
# `strip` needs no separate package -- gcc already depends on binutils.
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gcc \
      libc6-dev \
      make \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/gambit/gambit/archive/refs/tags/v${GAMBIT_VERSION}.tar.gz" -o /tmp/gambit.tar.gz \
    && echo "${GAMBIT_SHA256}  /tmp/gambit.tar.gz" | sha256sum -c - \
    && tar -C /tmp -xzf /tmp/gambit.tar.gz \
    && cd "/tmp/gambit-${GAMBIT_VERSION}" \
    && ./configure --prefix=/opt/gambit --enable-single-host \
    && make -j"$(nproc)" \
    && make install \
    && strip --strip-all /opt/gambit/bin/gsi /opt/gambit/bin/gsc \
    && rm -rf /tmp/gambit.tar.gz "/tmp/gambit-${GAMBIT_VERSION}"

FROM ubuntu:24.04
COPY --from=build /opt/gambit /opt/gambit
