[![pipeline status](https://gitlab.com/Silex777/docker-emacs/badges/master/pipeline.svg)](https://gitlab.com/Silex777/docker-emacs/-/commits/master)

# Description

Run Doom Emacs as a Scala IDE in Docker containers!

This version of the Doom Emacs container comes preconfigured such that
Scala Metals and Bloop are leveraged via the LSP. Custom LSP commands
for the Scala Mode are under the [Space]-m shortcut.

# Images

| OS                           | Tag                   | Size (MB) | Inherits from      | Contents                                        |
|------------------------------|-----------------------|-------|------------------------|-------------------------------------------------|
| [Ubuntu](https://ubuntu.com) | 27.2-ubuntu-20.04     | 3.59G | 27.2-ubuntu-20.04-dev  | Emacs, curl, gnupg & imagemagick                |
| [Ubuntu](https://ubuntu.com) | 27.2-ubuntu-20.04-dev | 1.83G | ubuntu:20.04           | All build dependencies & source in `/opt/emacs` |

*Other versions not found in the above chart are not functional/ready and are
still under development.*

# Usage

## To Build the Container

1. `cd` to `./27.2/ubuntu/20.04/`
1. run the following command from your shell:
   ```bash
   docker build \
   --build-arg username=$USER \
   --build-arg uid=$UID \
   -t josiah14/emacs:27.2-ubuntu-20.04 \
   .
   ```
1. Grab a Snickers and find something else to do, it's going to be a bit.

## To Run the Container

### Console

``` shell
docker run -it --rm josiah14/emacs:27.2-ubuntu-20.04
```

### GUI

``` shell
docker run -it --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v <absolute-src-path-of-your-code-directory>:<absolute-dest-path-of-your-code-directory> \
  josiah14/emacs:27.2-ubuntu-20.04
```

## On first boot of Doom Emacs from this image/container

Due to the limitations of Doom Emacs in some areas, there were a couple things which I could not
automate through the Dockerfile. They are relatively minor steps, but still need to be performed.

1. First boot will do some font and unicode mapping. Wait for this to complete.
1. You would think waiting for the GUI Emacs auto-started by the container would be enough to cache the
   unicode mapping once-and-for-all, but it's not. Now run `docker ps` to find the name of your
   container that's currently running Doom Emacs, and then run this `docker exec -it <name of container> bash`.
   Once in a Bash shell running in the container, run `emacs` to execute Doom Emacs again and wait
   again for the unicode mapping to finish.
1. Doom also has an issue where not all of the font symbols/icons it uses can be imported (as far as I can tell) from
   things like Nerd Fonts or Powerline Fonts. It has some special requirements that can be installed via a command
   in the Doom Emacs editor: `all-the-icons-install-fonts`. I learned about this [here](https://github.com/hlissner/doom-emacs/issues/724).
1. Now, once the above steps are completed, commit the current container to a
   Docker repo and tag of your choosing and everything should work fine on the next boot.
   You won't have to wait for the editor to perform the font and unicode mapping, and
   all of the icons should be there for the bottom editor status bar and the other plugins
   this version of Doom Emacs has installed.
1. If this still fails, follow the above steps a second time and it should resolve the issue.

## Known Issues

- If you notice that code completion and inference is not fully functioning (as
  in, the methods off of objects aren't getting indexed, for example), then you
  probably need to run `sbt bloopInstall` again. To fix this:
    - run `M-x lsp-metals-build-import` (`M-x` is `<Spc> :` in Doom Emacs)
    - In the lower right, just to the left of the rocketship icon, you should
      see some text indicating that `sbt bloopInstall` is running when the
      Emacs window is in focus. Be patient and wait for this to finish. After
      `sbt bloopInstall` it also runs through one or more `compile` commands.
      Once it's finished, LSP Metals will be fully functional.
    - If doing this doesn't work, from the project root of your Scala project,
      run `rm -rf ./.bloop` and then try the above 2 steps again.
    - If it still doesn't work, run `rm -rf ./.bloop && rm -rf ./.metals` from
      the Scala project's root dir, kill the editor/container, and run it again,
      and then wait for the full `sbt bloopInstall` process to complete after a
      full reinitialization of Metals for your project (the editor should ask
      you to import and initialize the project for Metals again just like
      anytime you execute the editor for the first time against a Scala project).
    - If you commit the container again after doing this, you shouldn't have
      this problem again on the same project. Note that this commit will
      significantly increase the size of your container (by ~600M, maybe more).
        - _Ways to reduce container size are being investigated. One potential is
          to store some things in container volumens instead. For now, I'm just
          using this container as an emergency "I have no functioning IDE and
          need something NOW!" solution._

# Alternatives

- [flycheck/emacs-cask](https://hub.docker.com/r/flycheck/emacs-cask): collection of docker images containing a
  minimal Emacs compiled from source with Cask.
- [flycheck/emacs-travis](https://github.com/flycheck/emacs-travis): makefile which provides targets to
  install Emacs stable and emacs-snapshot, Texinfo and Cask.
- [jgkamat/airy-docker-emacs](https://github.com/jgkamat/airy-docker-emacs): alpine-based docker images that have
  Emacs installed through the package manager.
- [JAremko/docker-emacs](https://github.com/JAremko/docker-emacs): collection of docker images with focus on GUI usage.
- [rejeep/evm](https://github.com/rejeep/evm): pre-built Emacs binaries.

# Contributions

They are very welcome! The basic workflow is as follow:

- Modify `images.yml`.
- Modify files inside the `/templates` directory.
- Run `bin/generate` to spread the changes everywhere.

# Thanks

- https://www.packet.com for the ARM servers allowing multiarch images.
