FROM ubuntu:24.04

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
ARG GUIX_VERSION=1.5.0
ARG GUIX_ARCH=x86_64
ARG GUIX_SHA256=aa41025489c5061543e9c48873eaa829b900b2da75d40f9648913622f5f47817
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Root-stage setup: apt deps for extracting the Guix binary tarball + runtime
# user + /gnu and /var/guix roots. xz-utils is required to extract it.
RUN set -eux \
 && apt-get update -y \
 && apt-get install -y --no-install-recommends \
        bats \
        ca-certificates \
        curl \
        sudo \
        xz-utils \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /etc/sudoers.d \
 && if id -u ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi \
 && if getent group ubuntu >/dev/null; then groupdel ubuntu; fi \
 && if getent group "${USER_GID}" >/dev/null; then \
      EXISTING_GROUP="$(getent group "${USER_GID}" | cut -d: -f1)"; \
      if [ "${EXISTING_GROUP}" != "${USERNAME}" ]; then groupdel "${EXISTING_GROUP}"; fi; \
    fi \
 && groupadd --gid "${USER_GID}" "${USERNAME}" \
 && if id -u "${USER_UID}" >/dev/null 2>&1; then \
      echo "UID ${USER_UID} is still occupied after deleting ubuntu"; \
      exit 1; \
    fi \
 && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
 && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
 && mkdir -m 0755 /gnu \
 && mkdir -p /var/guix \
 && chown -R ${USERNAME}:${USERNAME} /gnu /var/guix

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

# Install Guix from the official binary tarball. No guix-daemon involved at
# all: the tarball's store already contains a working `guile` (Guix is
# itself implemented in Guile, so a full Guile closure is already a
# transitive dependency of the `guix` package -- confirmed directly by
# extracting this exact tarball and finding it, live, before writing this
# file) even though the default profile only symlinks `guix` itself into its
# own bin/. Discover the store paths for both at build time rather than
# hardcoding their content-addressed hashes, which are tied to this exact
# GUIX_VERSION's build closure and would break on a version bump. Bundled in
# one RUN so a GUIX_VERSION bump invalidates the whole Guix layer.
RUN set -eux \
 && mkdir -p ~/guix-extract \
 && curl -fsSL "https://ftpmirror.gnu.org/gnu/guix/guix-binary-${GUIX_VERSION}.${GUIX_ARCH}-linux.tar.xz" \
        -o ~/guix-binary.tar.xz \
 && echo "${GUIX_SHA256}  $HOME/guix-binary.tar.xz" | sha256sum -c - \
 && tar -C ~/guix-extract -xf ~/guix-binary.tar.xz \
 && rm ~/guix-binary.tar.xz \
 && mv ~/guix-extract/gnu/store /gnu/store \
 && mv ~/guix-extract/var/guix/* /var/guix/ \
 && rm -rf ~/guix-extract \
 && mkdir -p ~/.local/bin \
 && GUIX_PROFILE="$(readlink -f /var/guix/profiles/per-user/root/current-guix)" \
 && GUILE_STORE_DIR="$(find /gnu/store -maxdepth 1 -iname '*-guile-3.*' ! -iname '*doc*' -printf '%f\n' | sort -V | tail -1)" \
 && for bin in guix guix-daemon; do ln -s "${GUIX_PROFILE}/bin/${bin}" ~/.local/bin/"${bin}"; done \
 && for bin in guile guild guile-config; do ln -s "/gnu/store/${GUILE_STORE_DIR}/bin/${bin}" ~/.local/bin/"${bin}"; done

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

CMD ["bash"]
