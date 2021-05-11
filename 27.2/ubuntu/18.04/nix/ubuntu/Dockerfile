FROM ubuntu:20.04

#COPY debian-bootstrap.sh /
#RUN bash /debian-bootstrap.sh

RUN apt-get update && \
   apt-get install -y \
           bzip2 \
           ca-certificates \
           curl \
           locales \
           sudo \
           xz-utils \
   && rm -rf /var/lib/apt/lists/*

#RUN groupadd -r -g 1000 emacs && useradd -r -m -g emacs -u 1000 emacs && adduser emacs sudo
RUN adduser --disabled-password --gecos '' emacs
RUN adduser emacs sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER emacs

RUN curl -L https://nixos.org/nix/install | sh
RUN .  /home/emacs/.nix-profile/etc/profile.d/nix.sh
ENV HOME=/home/emacs
ENV USER=emacs
#ENV NIX_PATH=nixpkgs=https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz
ENV NIX_PATH=${NIX_PATH:+$NIX_PATH:}$HOME/.nix-defexpr/channels
ENV NIX_PROFILES="/nix/var/nix/profiles/default $HOME/.nix-profile"

    # # Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
    # if [ -e /etc/ssl/certs/ca-certificates.crt ]; then # NixOS, Ubuntu, Debian, Gentoo, Arch
    #     export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    # elif [ -e /etc/ssl/ca-bundle.pem ]; then # openSUSE Tumbleweed
    #     export NIX_SSL_CERT_FILE=/etc/ssl/ca-bundle.pem
    # elif [ -e /etc/ssl/certs/ca-bundle.crt ]; then # Old NixOS
    #     export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
    # elif [ -e /etc/pki/tls/certs/ca-bundle.crt ]; then # Fedora, CentOS
    #     export NIX_SSL_CERT_FILE=/etc/pki/tls/certs/ca-bundle.crt
    # elif [ -e "$NIX_LINK/etc/ssl/certs/ca-bundle.crt" ]; then # fall back to cacert in Nix profile
    #     export NIX_SSL_CERT_FILE="$NIX_LINK/etc/ssl/certs/ca-bundle.crt"
    # elif [ -e "$NIX_LINK/etc/ca-bundle.crt" ]; then # old cacert in Nix profile
    #     export NIX_SSL_CERT_FILE="$NIX_LINK/etc/ca-bundle.crt"
    # fi

    # if [ -n "${MANPATH-}" ]; then
    #     export MANPATH="$NIX_LINK/share/man:$MANPATH"
    # fi

ENV PATH="$HOME/.nix-profile/bin:$PATH"

RUN nix-shell -p cachix --run "cachix use emacs-ci"
RUN nix-env -iA emacs-27-2 -f https://github.com/purcell/nix-emacs-ci/archive/master.tar.gz && \
    nix-collect-garbage

CMD ["emacs"]
