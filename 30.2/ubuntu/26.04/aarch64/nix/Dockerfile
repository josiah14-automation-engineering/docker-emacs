FROM ubuntu:26.04

ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000
ARG NIX_VERSION=2.34.7
ARG NIX_SHA256=e9d447ce3d2ff62d7ff9cb6ef401de6fa8acb148839dd00f7271945d7b638b14
ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=US/Chicago

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Root-stage setup: apt deps for the Nix installer + runtime user + /nix root.
# xz-utils is required to extract the Nix binary tarball the installer fetches.
RUN set -eux \
 && apt-get update -y \
 && apt-get install -y --no-install-recommends \
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
 && mkdir -m 0755 /nix \
 && chown ${USERNAME}:${USERNAME} /nix

USER ${USERNAME}
ENV USER=${USERNAME}
ENV HOME=/home/${USERNAME}

# Install Nix, enable flakes, install nil + direnv + nix-direnv into the user
# profile, then dedupe the store and drop caches/logs to minimise image size.
# Bundled in one RUN so a NIX_VERSION bump invalidates the whole Nix layer.
RUN set -eux \
 && curl -fsSL "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
        -o /tmp/nix-install \
 && echo "${NIX_SHA256}  /tmp/nix-install" | sha256sum -c - \
 && sh /tmp/nix-install --no-daemon \
 && rm /tmp/nix-install \
 && mkdir -p ~/.config/nix ~/.config/direnv \
 && printf 'experimental-features = auto-allocate-uids blake3-hashes ca-derivations cgroups configurable-impure-env dynamic-derivations external-builders fetch-closure fetch-tree flakes git-hashing impure-derivations local-overlay-store mounted-ssh-store nix-command parse-toml-timestamps pipe-operators recursive-nix verified-fetches\n' \
        > ~/.config/nix/nix.conf \
 && ~/.nix-profile/bin/nix profile install \
        nixpkgs#nil \
        nixpkgs#direnv \
        nixpkgs#nix-direnv \
        nixpkgs#bats \
 && printf 'source $HOME/.nix-profile/share/nix-direnv/direnvrc\n' \
        > ~/.config/direnv/direnvrc \
 && ~/.nix-profile/bin/nix store gc \
 && ~/.nix-profile/bin/nix store optimise \
 && rm -rf ~/.cache /nix/var/log

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

CMD ["bash"]
