ARG GAMBIT_VERSION=4.9.7
ARG GAMBIT_SHA256=0da7c9772a2186dab1fba6bf6c777afe7424f40beacadf1b117d5cc825fe2db3

# Reusable source image, same shape as josiah14/chez alongside it and
# josiah14/nix/josiah14/guix in systems-ide's own Dockerfile -- nothing
# here is ever `docker run` directly, only `COPY --from=` by a consumer.
# apt's gambc lags upstream (confirmed live: 4.9.3 on 26.04's own archive
# vs this v4.9.7, four releases behind), so this builds from the tagged
# GitHub source archive instead, matching Chez's own reasoning next door
# and this project's general bias against stale apt packages.
FROM ubuntu:26.04 AS build
ARG GAMBIT_VERSION
ARG GAMBIT_SHA256
ARG DEBIAN_FRONTEND=noninteractive

# Single RUN, chained end to end -- keeps this build stage to one layer.
# `strip` needs no separate package -- gcc already depends on binutils
# (confirmed live). Gambit's own INSTALL.txt confirms the source archive
# ships pregenerated .c files (the output of the Gambit compiler compiling
# itself at release time), so this needs no existing Scheme to bootstrap
# from -- a plain C compiler is enough, same "no chicken-and-egg problem"
# shape as Chez's own boot files. `--enable-single-host` is upstream's own
# documented recommendation for build speed and executable compactness.
# GitHub's own tag archive is used rather than a curated release asset
# because Gambit publishes no GitHub Releases at all (confirmed live: the
# repo's Releases page is empty) -- git tags are the only versioned
# source available.
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

FROM ubuntu:26.04
COPY --from=build /opt/gambit /opt/gambit
