# Smoke Test

Run these inside the container after a successful `./build.sh`. Drop in with `./run.sh`.

**Tools and versions**
```bash
guix --version    # guix (GNU Guix) 1.5.0
guile --version   # guile (GNU Guile) 3.0.9
```

**No daemon**

This image never runs `guix-daemon` -- there's no package install at build
time, so there's nothing for a daemon to do here. `guile` is present because
Guix is itself implemented in Guile, so a full Guile closure is already a
transitive dependency of the `guix` package in the store; it's just not
symlinked into `guix`'s own profile `bin/` by default, hence the direct
store-path symlink in the Dockerfile instead of a `guix install guile` step.

```bash
pgrep -f guix-daemon   # nothing -- exit status 1
```

**Profile**
```bash
ls -l ~/.local/bin | grep -E ' (guix|guile|guild) ->'
```

**Language**
```bash
guile -c '(display (+ 1 2)) (newline)'   # 3
```

**Image size sanity**
```bash
du -sh /gnu   # a few hundred MB -- just the guix + guile closures, nothing installed
```
