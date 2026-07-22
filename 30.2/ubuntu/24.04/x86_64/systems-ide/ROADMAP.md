# ROADMAP

The systems-ide starts from a working bare Doom base (cross-language tooling
only) and adds language support one at a time. Each step has a Dockerfile
change and a config change. Verify each addition builds and works before moving
to the next.

---

## Step 1: Shell (bash/sh/zsh/ksh) — [#1](https://github.com/josiah14-automation-engineering/docker-emacs/issues/1)

Configuration complete, build pending.

Scope expanded from bash/sh to bash, sh, zsh, and ksh. Full details in BUILDLOG.

**What was built:**
- `bash-language-server@5.6.0` (npm) for LSP; `shellcheck` for diagnostics
- `zshdb` + `realgud` for zsh debugging
- `shell.el`: `bash-mode`, `zsh-mode`, `ksh-mode` derived from `sh-mode`;
  `register-shell-file-patterns` to wire dotfile and extension patterns;
  `lsp-bash-shellcheck-arguments "-x"` (shebang auto-detection, no `-s` override)
- `sh-keybindings.el`: `SPC m e e/b` execute, `SPC m r r` rename,
  `SPC m d d` zshdb, `SPC m s s` set shell dialect

**Known gap:**
- Debugger binding (`SPC m d d`) invokes `realgud:zshdb` from `sh-mode-map` —
  activates in bash/ksh buffers where it is incorrect. `realgud:bashdb` deferred
  until `bashdb` is added to the image and a dispatch function is written.

**Verify (when built):**
- Open a `.sh` file; confirm LSP completions and flycheck diagnostics
- Open a `.zshrc`; confirm modeline shows "ZSH" not "Shell[bash]"
- Run `which bash-language-server` and `which shellcheck` inside the container
- Run `M-x realgud:zshdb` on a zsh script; confirm debugger launches

---

## ~~Step 2: Go~~ — [#2](https://github.com/josiah14-automation-engineering/docker-emacs/issues/2) ✓ COMPLETE

Full Go IDE working: gopls, flycheck-golangci-lint, gotests, gorepl, go-tag, playground
URL yank, all keybindings verified. Flight test 100% checked off. Closed 2026-06-05.

---

## Step 3: Nix — [#10](https://github.com/josiah14-automation-engineering/docker-emacs/issues/10)

Prioritized above Nushell and systems languages — full Nix installation needed to support
projects using nix flakes.

**Architecture decision:** Nix is expected in every IDE, not just systems-ide. Rather than
duplicating the install block in each Dockerfile, Nix is extracted into a standalone
published image (`josiah14/nix:2.33.3-ubuntu-24.04`) at
`30.2/ubuntu/24.04/x86_64/nix/`. IDE Dockerfiles derive from it via multi-stage COPY,
the same pattern used for the emacs-build dev image.

### ✓ nix-source image built and verified (2026-06-06)

`30.2/ubuntu/24.04/x86_64/nix/` — Dockerfile, build.sh, run.sh, SMOKETEST.md.

What it contains:
- Ubuntu 24.04 base, minimal apt deps
- Runtime user creation (matches host UID/GID via build-arg)
- Nix 2.33.3 `--no-daemon`, SHA-verified installer
- All 19 capability experimental features enabled in `~/.config/nix/nix.conf`
- `nix profile install nixpkgs#nil nixpkgs#direnv nixpkgs#nix-direnv`
- `~/.config/direnv/direnvrc` wired to source nix-direnv hook
- `nix store gc` + `nix store optimise` + `rm -rf ~/.cache /nix/var/log` at build end

Smoketest passed: nil, direnv, nix-direnv all verified; flake dev shell end-to-end
with `nix develop` and direnv + nix-direnv hook both confirmed working.

### Remaining for systems-ide

**Dockerfile (Task #3):**
- Add `FROM josiah14/nix:2.33.3-ubuntu-24.04 AS nix-source`
- Remove inline nix install block and `/nix` mkdir; remove `direnv` from apt
- Add `COPY --from=nix-source --chown=${USER_UID}:${USER_GID}` for:
  `/nix`, `~/.nix-profile`, `~/.nix-channels`, `~/.local/state/nix`,
  `~/.config/nix`, `~/.config/direnv`
- Add `ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"`

**init.el (Task #4):**
- Add `(nix +lsp)` to `:lang`

**config.el (Task #4):**
- Add `(load! "nix-keybindings")`

**BATS smoketest (Task #6):**
- Install `nixpkgs#bats` in the nix image alongside nil/direnv/nix-direnv
- Write `smoketest.bats` in `nix/`; add `--test` flag to `run.sh`
- SMOKETEST.md stays as human-readable reference

**Verify (after systems-ide rebuild):**
- `nix --version` and `nil --version` inside the container
- Open a `.nix` file; confirm nil provides completions and go-to-definition
- Open a project with `flake.nix` + `.envrc` using `use flake`; confirm direnv activates

---

## Step 4: Nushell — [#3](https://github.com/josiah14-automation-engineering/docker-emacs/issues/3)

Prioritized above the systems languages — support scripts in the FaradAI rewrite
target Nu. Doom has no native Nushell module; requires manual wiring. `nu --lsp`
is the built-in LSP server (available since Nu 0.85).

**Dockerfile:**
- Download the Nu binary from GitHub releases (use the `musl` release for a
  statically-linked binary with no libc dependency):
  ```dockerfile
  ARG NU_VERSION=<pin>
  ARG NU_SHA256=<pin>
  RUN curl -fsSL \
        "https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/nu.tar.gz \
      && echo "${NU_SHA256}  /tmp/nu.tar.gz" | sha256sum -c - \
      && tar -xzf /tmp/nu.tar.gz --strip-components=1 \
           -C /usr/local/bin \
           "nu-${NU_VERSION}-x86_64-unknown-linux-musl/nu" \
      && rm /tmp/nu.tar.gz
  ```
  Pin version: check https://github.com/nushell/nushell/releases for current stable.

**packages.el:**
- Add `(package! nushell-mode)` — provides syntax highlighting and major mode

**config.el:**
- Associate `.nu` files with `nushell-mode` and enable LSP:
  ```elisp
  (add-to-list 'auto-mode-alist '("\\.nu\\'" . nushell-mode))

  (with-eval-after-load 'lsp-mode
    (add-to-list 'lsp-language-id-configuration '(nushell-mode . "nushell"))
    (lsp-register-client
     (make-lsp-client :new-connection (lsp-stdio-connection '("nu" "--lsp"))
                      :major-modes '(nushell-mode)
                      :server-id 'nushell-lsp)))
  ```
- Add `(load! "nu-keybindings")`

**Verify:**
- Open a `.nu` file; confirm `nushell-mode` activates and syntax highlighting fires
- Confirm LSP completions and hover docs via `nu --lsp`
- Run `nu --version` inside the container

---

## Step 5: C — [#4](https://github.com/josiah14-automation-engineering/docker-emacs/issues/4)

**Dockerfile:**
- Add `gcc clangd gdb` to the apt list
- No new build stage needed

**init.el:**
- Add `(cc +lsp)` to `:lang`

**config.el:**
- Add `(load! "c-keybindings")`
- Add C style preferences:
  ```elisp
  (setq c-default-style "linux"
        c-basic-offset 4)
  ```

**Verify:** Open a `.c` file; confirm clangd completions and flycheck errors.
Run `M-x dap-debug` with a gdb configuration to confirm debugging works.

---

## Step 6: C++ — [#5](https://github.com/josiah14-automation-engineering/docker-emacs/issues/5)

C++ is covered by the same `:lang (cc +lsp)` module as C. No Doom or Dockerfile
changes needed if Step 4 is complete. This step is about verifying and configuring:

**Dockerfile:**
- Add `g++ clang` to the apt list (clang++ comes with clang)

**config.el:**
- Confirm `c-default-style` applies to C++ buffers. Add a `c++-mode` hook if
  separate style settings are needed.

**Verify:** Open a `.cpp` file; confirm clangd works. Test with a `CMakeLists.txt`
project to confirm `compile_commands.json`-based navigation works across files.

---

## Step 7: Rust — [#6](https://github.com/josiah14-automation-engineering/docker-emacs/issues/6)

Rust requires rustup, which installs to `~/.cargo` as the runtime user. This means
the install runs in the final image as the user, after the user switch.

**config.el:**
- Add `(load! "rust-keybindings")`

**Dockerfile:**
- Add `ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"` after the user switch
- Add a `RUN` step as the user:
  ```dockerfile
  RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
           | sh -s -- -y --no-modify-path --default-toolchain stable \
      && ~/.cargo/bin/rustup component add rust-analyzer rust-src
  ```
- TODO: pin rustup installer sha256 before adding this step (see [#16](https://github.com/josiah14-automation-engineering/docker-emacs/issues/16))

**init.el:**
- Add `(rust +lsp)` to `:lang`

**Verify:** Open a `.rs` file; confirm rust-analyzer completions, go-to-definition
into std, and flycheck errors. Run `rustc --version` inside the container.

**Debugging (deferred):** Wire codelldb for Rust debugging — see [#17](https://github.com/josiah14-automation-engineering/docker-emacs/issues/17).

---

## Step 8: Zig — [#7](https://github.com/josiah14-automation-engineering/docker-emacs/issues/7)

Zig requires a separate build stage to isolate the toolchain download.

**Dockerfile:**
- Add `zig-build` stage before the final stage:
  ```dockerfile
  FROM ubuntu:24.04 AS zig-build
  ARG ZIG_VERSION=<pin>
  ARG ZIG_SHA512=<pin>
  RUN apt-get update -y && apt-get install -y ca-certificates curl xz-utils ...
  RUN curl ... | sha512sum -c - && tar -xf ... -C /usr/local/zig
  ```
- Add `ZLS_VERSION` and `ZLS_SHA512` ARGs; download ZLS binary alongside Zig
- In final stage: `COPY --from=zig-build /usr/local/zig /usr/local/zig`
- Add `/usr/local/zig` to `ENV PATH`
- Pin versions: check ziglang.org for current stable; ZLS must match Zig version exactly

**init.el:**
- Add `zig` to `:lang` (no `+lsp` flag needed; Doom's zig module auto-detects zls on PATH)

**config.el:**
- Add `(load! "zig-keybindings")`

**Verify:** Open a `.zig` file; confirm zls completions. Run `zig version` and
`zls --version` inside the container.

---

## Step 9: CMake — [#8](https://github.com/josiah14-automation-engineering/docker-emacs/issues/8)

Natural addition after C/C++. Lightweight — cmake-language-server is a pip package.

**Dockerfile:**
- Add `python3 python3-pip` to the apt list (if not already present)
- Add `RUN pip3 install --break-system-packages cmake-language-server`

**init.el:**
- Add `cmake` to `:lang`

**config.el:**
- Add `(load! "cmake-keybindings")`

**Verify:** Open a `CMakeLists.txt`; confirm completions and hover docs.

---

## Step 10: Lua — [#9](https://github.com/josiah14-automation-engineering/docker-emacs/issues/9)

Lua is embedded in nginx, Redis, Neovim config, and embedded firmware.
lua-language-server is distributed as a pre-built binary.

**Dockerfile:**
- Add `lua5.4` to the apt list (runtime)
- Download lua-language-server binary from GitHub releases:
  https://github.com/LuaLS/lua-language-server/releases
  Pin version and sha512; extract to `/usr/local/bin`

**init.el:**
- Add `(lua +lsp)` to `:lang`

**config.el:**
- Add `(load! "lua-keybindings")`

**Verify:** Open a `.lua` file; confirm completions. Run `lua5.4 --version`
and `lua-language-server --version` inside the container.

---

## ~~Step 11: Guile / Scheme~~ — [#11](https://github.com/josiah14-automation-engineering/docker-emacs/issues/11) ✓ CODE COMPLETE (aarch64-verified, x86_64 build-untested)

Uses Geiser (REPL integration) rather than LSP — the correct Emacs-idiomatic
approach for interactive Lisp development. Guile earns full-tier support
specifically because it's the implementation language of GNU Guix (the
Nix-equivalent in the Scheme world), not just general GNU-ecosystem affinity.

**Architecture decision: Guile is sourced from a standalone `guix-source`
image, not a plain apt install.** Same pattern as Step 3's Nix — Ubuntu's
apt `guile-3.0` and Guix's own bundled Guile only match by version
coincidence (Ubuntu freezes at release time; Guix keeps moving), and the
real intent is working with Guix's own package/channel definitions through
Geiser later, which needs Guix's own Guile module load path. Verified live
(aarch64) that no `guix-daemon` is needed to get a working `guile` out of
the tarball at all: Guix is itself implemented in Guile, so a full Guile
closure is already a transitive dependency of the `guix` package in the
store — it's just not symlinked into `guix`'s own profile `bin/` by
default. See `30.2/ubuntu/*/guix/` (both trees) and the aarch64 tree's
DECISIONLOG.md for the full reasoning trail, including the reversed
initial recommendation.

**Dockerfile:**
- `FROM josiah14/guix:1.5.0-ubuntu-24.04 AS guix-source`
- `COPY --from=guix-source /gnu /gnu` and `/var/guix /var/guix`
- Symlink `guix`/`guix-daemon`/`guile`/`guild`/`guile-config` into
  `~/.local/bin` (already on `PATH`), discovering the exact
  content-addressed store paths at build time rather than hardcoding them

**init.el:**
- Add `(scheme +guile)` to `:lang`, between `(rust +lsp)` and `(sh +lsp)`

**config.el:**
- Add `(load! "guile-keybindings")` — no separate `guile-config.el`, no
  `packages.el` entry needed: Doom's own `lang/scheme/config.el` already
  wires everything

**Guix package management (Phase 3):** `guix-daemon` runs self-contained
inside the container, started by a new `entrypoint.sh` at container
startup — needs `--security-opt seccomp=unconfined --cap-add SYS_ADMIN
--cap-add NET_ADMIN` on `docker run` (all three confirmed required on
aarch64, for Guix's build sandbox's own `personality()`/`clone()`/
loopback-interface calls). See the aarch64 tree's DECISIONLOG.md.

**Status:** all of the above is mirrored byte-for-byte from the aarch64
tree (which has a full 76/78 smoketest pass, including all 4
Guile-specific tests) — this x86_64 tree has **not** been build-tested
this session (no x86_64 emulation available on the aarch64 host used
for verification). Treat as code-complete but unverified until an
actual x86_64 build + smoketest run confirms it.

---

## Step 11.5: Racket + Rash

No GitHub issue yet. Comes after Guile deliberately — same Scheme family,
same Geiser-based REPL-first philosophy, worth doing back to back. Rash is
a `#lang rash` shell-scripting DSL built directly on Racket, chosen over
`scsh` (confirmed dormant -- last stable release 2006, ~20 years without
active maintenance, fails this project's own "boring, reproducible,
actively-maintained dependency" standard, see AGENTS.md) as the actual
systems-scripting answer in this family. Racket's own apt package version
vs. the official `.sh` installer needs a real comparison before picking —
TODO, verify current Ubuntu 24.04/26.04 apt package freshness against
https://download.racket-lang.org/ before deciding.

**Dockerfile:**
- Install Racket -- TODO: apt `racket` package vs. official installer,
  pin whichever is chosen (version + checksum, matching every other
  language install in this file)
- `raco pkg install rash` once Racket itself is installed (rides on
  Racket's own package manager, no separate toolchain)

**init.el / packages.el:**
- Check for a Doom `:lang racket` module first (unconfirmed -- verify
  against the pinned Doom commit before assuming one exists, same
  caveat as Crystal below). If none, `(package! racket-mode)` (Greg
  Hendershott's package -- the de facto standard standalone Racket mode
  for Emacs, provides major-mode + REPL + basic debugging support) is
  the fallback.

**config.el:**
- Add `(load! "racket-keybindings")` (new file)

**Verify:** Open a `.rkt` file; confirm `racket-mode` (or Doom's module)
activates, REPL starts, completions/hover work. Open a `#lang rash` file;
confirm mode detection and REPL send-to-process both work the same way.
Run `racket --version` and confirm `rash` is requireable inside the
container.

---

## Step 11.6: Crystal

No GitHub issue yet. Comes after Racket + Rash.

**Two real caveats to weigh before starting, not glossed over:**
- `crystalline` (the only actively-maintained Crystal LSP server) is
  explicitly documented as unable to provide full-featured language
  server capabilities "due to the nature of the Crystal language and the
  way the compiler works" -- a compiler-architecture limitation, not
  just an immature-ecosystem one. Verify live (open a real `.cr` file,
  check what actually works -- completions, go-to-def, hover) before
  assuming this is "done" the way Rust/Go's LSP support is.
- Verify Doom's own `:lang crystal` module (referenced in Doom's
  v21.12-era docs) is still present and functional in the exact Doom
  commit this project currently pins -- unconfirmed as of this writing.
  If it's gone or broken, `crystal-mode.el` (crystal-lang-tools,
  ruby-mode-derived) + manual LSP client registration is the fallback,
  same shape as this file's TOML/Nushell steps below.

**Dockerfile:**
- Crystal is not in Ubuntu's default repos -- needs its own apt source
  added (check crystal-lang.org's own install instructions for the
  current recommended method) or the official install script, pinned.
  Crystal 1.20.2 (current as of this writing) ships official ARM64
  Linux builds -- confirm this covers the aarch64/M2 target specifically
  before assuming parity with the x86_64 port is free.
- Install `crystalline` (check its own distribution method -- `shards
  build` from source vs. prebuilt release binaries, unconfirmed)
- Install `icr`/`ic` (Interactive Console for Crystal -- what
  `inf-crystal.el` connects to, and what actually implements Crystal's
  "crystal pry" REPL-debugging functionality)

**init.el / packages.el:**
- Try Doom's `:lang crystal` module first (see caveat above). Fallback:
  `(package! crystal-mode)` + `(package! inf-crystal)`

**config.el:**
- Add `(load! "crystal-keybindings")` (new file)
- Wire `inf-crystal-minor-mode` onto `crystal-mode-hook` if not already
  handled by Doom's module
- No dape/DAP entry needed -- debugging goes through the built-in
  `debugger` keyword (drops into an interpreted session via Crystal's
  own interpreter mode, not a compiled-binary debugger) accessed through
  `inf-crystal`'s REPL buffer, the same shape as Ruby's `binding.pry`
  through `inf-ruby` -- deliberately lighter-weight than a structured
  DAP debugger, not a lesser version of one. See DECISIONLOG.md's
  Ruby/pry entry for the precedent this follows.

**Verify:** Open a `.cr` file; confirm major-mode activates and note
exactly which LSP features actually work given the known crystalline
limitation above -- don't just confirm "LSP connects." Place a
`debugger` call in a real script, run it under `inf-crystal`, confirm
`step`/`next`/`finish`/`continue`/`whereami` all work through the REPL
buffer. Run `crystal --version` and `crystalline --version` inside the
container.

---

## Step 12: TOML — [#12](https://github.com/josiah14-automation-engineering/docker-emacs/issues/12)

No Doom module exists for TOML. Requires manual mode + LSP wiring.

**Dockerfile:**
- Download `taplo` binary from GitHub releases:
  https://github.com/tamasfe/taplo/releases
  Pin version and sha512; install to `/usr/local/bin`

**packages.el:**
- Add `(package! toml-mode)`

**config.el:**
- Add taplo LSP client registration:
  ```elisp
  (with-eval-after-load 'lsp-mode
    (add-to-list 'lsp-language-id-configuration '(toml-mode . "toml"))
    (lsp-register-client
     (make-lsp-client :new-connection (lsp-stdio-connection "taplo lsp stdio")
                      :major-modes '(toml-mode)
                      :server-id 'taplo)))
  ```

**Verify:** Open a `Cargo.toml`; confirm taplo provides schema-aware completions.

---

## Step 13: Assembly — [#13](https://github.com/josiah14-automation-engineering/docker-emacs/issues/13)

Syntax only — no LSP, no debugger integration needed beyond what gdb already provides.

**init.el:**
- Add `asm` to `:lang`

**Verify:** Open a `.asm` or `.s` file; confirm syntax highlighting.

---

## Step 14: Syntax-only batch — [#14](https://github.com/josiah14-automation-engineering/docker-emacs/issues/14)

All lightweight. Add to init.el in one go; no Dockerfile changes.

**Dockerfile:**
- Add `ruby perl fish` to the apt list (runtimes for running scripts, not just reading)

**init.el:**
- Add to `:lang`: `(python)`, `ruby`, `perl`

**packages.el:**
- Add `(package! fish-mode)` — Fish is not covered by `:lang sh`

**Verify:** Open one file of each type; confirm syntax highlighting fires.

---

## Hardening (after all steps)

Once all languages are working:

1. **Generate straight.el lockfile** — [#15](https://github.com/josiah14-automation-engineering/docker-emacs/issues/15)
   Walk `~/.config/emacs/.local/straight/repos/` and produce `straight-versions.el`,
   then `COPY` it into the Dockerfile before the final `doom sync`. Pins all 400+
   packages to exact commits for reproducible builds.

2. **Pin rustup installer sha256** — [#16](https://github.com/josiah14-automation-engineering/docker-emacs/issues/16)
   Record the sha256 of `sh.rustup.rs` at build time and add a verification step
   before piping to sh.

3. **Wire codelldb for Rust/Zig debugging** — [#17](https://github.com/josiah14-automation-engineering/docker-emacs/issues/17)
   See Step 6 notes.

4. **Wire dap-gdb-lldb for C/C++ debugging** — [#18](https://github.com/josiah14-automation-engineering/docker-emacs/issues/18)
   Add `(require 'dap-gdb-lldb)` to config.el and document a sample launch
   configuration.

5. **Add GNOME launcher** — [#19](https://github.com/josiah14-automation-engineering/docker-emacs/issues/19)
   Mirror the mercury-ide `host/` pattern: a launch script and `.desktop` entry
   for one-click GUI launch from the application menu.

---

## Future enhancements

- **goenv multi-version Go management** — [#20](https://github.com/josiah14-automation-engineering/docker-emacs/issues/20)
  Currently using native Go toolchain management (see DECISIONLOG.md). Revisit
  if pre-1.21 project support or offline builds become a requirement.

- **Fix `shell-mode-hook` not firing in Doom Emacs** — `:!` commands (Evil-ex shell
  escape) fail because `shell-mode-hook` doesn't fire correctly. Needs investigation
  into how Doom initialises the shell; may require explicit wiring in `config.el` or
  `shell.el`.

- **Fix `gorepl-eval-region` double-indentation** — [#21](https://github.com/josiah14-automation-engineering/docker-emacs/issues/21)
  Sending a multi-line region to the REPL via `SPC m r E` corrupts indentation —
  gore's `liner` readline library auto-indents on top of existing indentation.
  Potential fix: bracketed paste escape sequences or dedenting before send. Needs
  investigation into whether `liner` supports bracketed paste mode.
