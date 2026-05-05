# docker-emacs

Personal Doom Emacs IDE images for multiple languages, built on Docker. Each image is a fully compiled Emacs with a language-specific Doom configuration baked in — ready to run as a GUI or console IDE.

## Images

Each Emacs version/OS combination has a **dev** image (compiles Emacs from source) and one or more **IDE** images built on top of it.

| Emacs | OS | Arch | IDE | Image tag |
|---|---|---|---|---|
| 30.2 | Ubuntu 24.04 | x86_64 | dev | `josiah14/emacs:30.2-skylake-ubuntu-24.04-dev` |
| 30.2 | Ubuntu 24.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04` |
| 29.2 | Ubuntu 24.04 | x86_64 | dev | `josiah14/emacs:29.2-skylake-ubuntu-24.04-dev` |
| 29.2 | Ubuntu 24.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:29.2-skylake-ubuntu-24.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | dev | `josiah14/emacs:29.2-skylake-ubuntu-22.04-dev` |
| 29.2 | Ubuntu 22.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | Mercury | `josiah14/mercury-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | x86_64 | Haskell | `josiah14/haskell-doom-emacs-ide:29.2-x86_64-ubuntu-22.04` |
| 29.2 | Ubuntu 22.04 | aarch64 | dev | `josiah14/emacs:29.2-ubuntu-22.04-aarch64-dev` |
| 29.2 | Alpine 3.20.2 | aarch64 | dev | `josiah14/emacs:29.2-alpine-3.20.2-aarch64-dev` |
| 28.1 | Ubuntu 22.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 22.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 22.04 | x86_64 | 47deg Scala | `josiah14/47deg-scala-doom-emacs-ide:28.1-ubuntu-22.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:28.1-ubuntu-20.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:28.1-ubuntu-20.04` |
| 28.1 | Ubuntu 20.04 | x86_64 | 47deg Scala | `josiah14/47deg-scala-doom-emacs-ide:28.1-ubuntu-20.04` |
| 27.2 | Ubuntu 20.04 | x86_64 | Python | `josiah14/python-doom-emacs-ide:27.2-ubuntu-20.04` |
| 27.2 | Ubuntu 20.04 | x86_64 | Scala | `josiah14/scala-doom-emacs-ide:27.2-ubuntu-20.04` |

## Building

Each IDE directory contains a `build.sh` that runs `docker build` with the correct args. To build the 30.2 Mercury IDE:

```bash
cd 30.2/ubuntu/24.04/x86_64/dev
./build.sh            # build the dev image first

cd ../mercury-ide
./build.sh            # build the IDE image
```

If a `build.sh` is absent (older images), build manually from the IDE directory:

```bash
docker build \
  --ulimit nofile=262144:262144 \
  --build-arg username=$USER \
  --build-arg uid=$UID \
  --build-arg fullname="Your Name" \
  --build-arg email="you@example.com" \
  -t josiah14/python-doom-emacs-ide:28.1-ubuntu-22.04 \
  .
```

Builds take a while — Emacs compiles from source in the dev image, and `doom sync` runs with AOT compilation in the IDE image.

## Running

### Console

```bash
docker run -it --rm josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04
```

### GUI

```bash
docker run -it --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /path/to/your/project:/path/to/your/project \
  josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04
```

## On first boot

Due to limitations in Doom Emacs, a couple of steps can't be automated through the Dockerfile and need to be done manually after the first run.

1. First boot will perform font and unicode mapping. Wait for it to complete before doing anything else.
1. That first pass isn't enough to cache the unicode mapping permanently. Find the running container name with `docker ps`, then run `docker exec -it <container-name> bash`. From inside the container, run `emacs` a second time and wait for the unicode mapping to finish again.
1. Install the icon fonts Doom needs but can't bundle automatically. Inside Emacs, run `M-x all-the-icons-install-fonts` (in Doom, `M-x` is `SPC :`).
1. Commit the container to a new image so you don't repeat these steps:
   ```bash
   docker commit <container-name> <your-image-name>:ready
   ```
1. From here on, boot from the committed image — fonts and unicode will be cached and icons will be present.

If icons are still missing after these steps, repeat them once more.

## Alternatives

- [flycheck/emacs-cask](https://hub.docker.com/r/flycheck/emacs-cask): minimal Emacs compiled from source with Cask
- [jgkamat/airy-docker-emacs](https://github.com/jgkamat/airy-docker-emacs): Alpine-based images with Emacs from the package manager
- [JAremko/docker-emacs](https://github.com/JAremko/docker-emacs): Docker images focused on GUI usage
- [rejeep/evm](https://github.com/rejeep/evm): pre-built Emacs binaries
