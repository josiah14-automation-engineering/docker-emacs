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

**Currently just a stub, not started**: `zig-keybindings.el` exists but is an
empty placeholder never actually loaded from `config.el`, and there's no
`zig` in `init.el`'s `:lang` block or any Zig toolchain install in the
Dockerfile at all (confirmed directly against all three files in both
trees, not assumed from this section's old text). This section rewrites
the plan below with live-verified specifics, replacing the earlier
generic sketch (which had the `+lsp` recommendation backwards and no
debugger-integration research at all).

**Versions confirmed live today** (mirror.racket-lang.org-style
paranoia, not trusted from any prior note): Zig 0.16.0 is current
stable (`ziglang.org/download/index.json`), and ZLS 0.16.0 is the
exact matching release (`zigtools/zls` GitHub releases) — same
"LSP version must match the toolchain version exactly" constraint
this file already flags for Zig. Both publish prebuilt
`aarch64-linux`/`x86_64-linux` tarballs. Zig's own index.json publishes
a `shasum` field directly (confirmed by re-downloading and re-hashing:
`ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17` for
`zig-aarch64-linux-0.16.0.tar.xz`, matches). ZLS publishes only
`.minisig` signatures, no plain checksum file (same as lua-language-server/
stylua elsewhere in this file) — sha256 computed directly against the
real release assets rather than left as a placeholder:
`430cd293d201eb70ae2519dbc96c854bf8791b8df7fc9392e8d2dc9680a2bed7`
(`zls-aarch64-linux.tar.xz`), `ded6d562a0b86ee878b1ddf70ffab2797ce3cdca3b02d6077548f9d56dff96b6`
(`zls-x86_64-linux.tar.xz`). Re-verify both at actual implementation
time regardless — these are today's numbers, not a permanent pin.

**Dockerfile — simpler than this section's old sketch, no separate
build stage needed:** Zig ships as a self-contained directory (the
`zig` binary plus its own bundled `lib/` standard library sitting next
to it — not independently relocatable the way a single static binary
like `ruff`/`stylua` is), so it needs the same "extract whole directory,
add it directly to PATH" treatment as `lua-language-server` gets below,
not a symlink into `~/.local/bin` (which would separate the binary from
the `lib/` it needs beside it). ZLS by contrast *is* a single
relocatable binary — same `curl | sha256sum -c | tar | install` pattern
as `ruff`/`stylua`. Go's separate `go-build` stage above is this file's
oldest pattern and isn't what current single-binary/single-directory
tools in this Dockerfile do (`nu`/`ruff`/`stylua`/`lua-language-server`
all install directly in the final stage, post-`USER` switch, no
isolated build stage) — Zig needs no build stage either, it's just an
extract, matching the newer/simpler convention rather than the old
Go-era one.

**init.el:**
- Add `(zig +lsp)` to `:lang` — **correcting this section's earlier
  claim**: the `+lsp` flag *is* needed and is what Doom's own zig
  module README explicitly recommends ("It is highly recommended you
  use this"), it just doesn't gate on a separate flag for zls
  autodetection the way some other `+lsp`-flagged modules do extra
  work; the flag still has to be present for LSP to activate at all.

**config.el / packages.el:** Likely nothing, **delete the
`zig-keybindings.el` stub rather than filling it in** — confirmed
directly from the pinned Doom commit's `modules/lang/zig/config.el`
that it already wires a full localleader map (`b` compile, `f`
zig-format-buffer, `r` run, `t` test-buffer) and its own `flycheck`
checker (`zig ast-check`) with zero extra config needed, the same "Doom's
own module is already built out" shape Racket's Step 11.5 found. Verify
this live before assuming, same as Racket.
- **Formatting already correct with no override needed:** `zig fmt` is
  apheleia's own built-in default for `zig-mode`/`zig-ts-mode`
  (confirmed directly in `apheleia-formatters.el`), and Doom's zig
  `config.el` explicitly sets `zig-format-on-save nil` "rely on
  `:editor format` instead" — this image's global `(format +onsave)`
  flag (`init.el`) already covers it.
- `+tree-sitter` flag deliberately left off for the same reason Racket
  left `+hash-lang` off: adds a grammar-compile step and a second mode
  (`zig-ts-mode`) for no concretely-needed benefit yet; plain
  `zig-mode` already gets full LSP. Revisit if a real need shows up.

**Debugger — two real, concrete gaps, found by reading `dape-config.el`
directly, not assumed:**
1. `lldb-dap`/`lldb-vscode`'s `modes` list (set in this file's own
   `dape-config.el`) has no `zig-mode` entry — same class of gap
   already fixed for `asm-mode` on the `gdb` config (see this file's
   own comment there). Needs the same one-line `plist-put` append,
   scoped to `lldb-dap`/`lldb-vscode` instead of `gdb` (Zig debugging
   is an lldb job, matching Rust, not a gdb one).
2. `+dape-resolve-cwd`'s marker list only checks `Cargo.toml`/
   `CMakeLists.txt` — needs `build.zig` added, or a lone `.zig` file
   with no `build.zig` anywhere up the tree hits the exact "//"
   fallback bug this file already documents for Assembly. Separately,
   `+dape-resolve-program` (cargo → CMake → literal "a.out" fallback)
   needs a `+dape-zig-program` analog: **unverified hypothesis, confirm
   live before implementing** — `zig build` conventionally places its
   output at `zig-out/bin/<artifact-name>` relative to the `build.zig`
   root, while a lone-file `zig build-exe foo.zig` compile produces
   `./foo` (source basename, no extension) in the current directory.
   Don't trust this without running both cases for real, the same
   "verify a resolver's fallback, not just its happy path" discipline
   AGENTS.md already calls out.

**Verify:** Open a `.zig` file inside a real `build.zig` project (not
just a lone file, matching AGENTS.md's "test the nested case on
purpose" rule); confirm `zig-mode` activates, zls connects
(`lsp-workspaces`), `zig fmt` format-on-save works via `SPC m f`,
and a real breakpoint/continue/inspect cycle works through
`lldb-dap` once the two debugger gaps above are fixed. Run `zig version`
and `zls --version` inside the container.

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

## ~~Step 11.5: Racket + Rash~~ ✓ CODE COMPLETE (aarch64-verified, x86_64 build-untested)

**Both Racket and Rash implemented on the aarch64 tree and verified live**
(2026-07-23), source changes mirrored here: `racket-mode` activates for
both `#lang racket` and `#lang rash` files (same `.rkt` extension),
`racket-langserver` connects to both (1732 real completions in the rash
file, including rash-specific bindings — the "does racket-langserver's
analysis hold up for a non-core #lang" question below is answered yes),
the REPL runs correctly, and `raco fmt` format-on-save works end-to-end.
Rash's go/no-go (flagged below) was answered explicitly: implement it,
per Josiah's call that the maintainer still actively uses it day-to-day,
unlike scsh's genuine 20-year abandonment. Zero new elisp files needed —
Doom's own `lang/racket/config.el` was already fully built out, same
shape as Guile's own `scheme` module. Full details, plus two real
non-obvious findings (apheleia's lazy engine-load affecting
first-save-of-a-session for any Doom-customized formatter, and Racket's
own localleader `f` binding colliding with the generic format keybinding)
in BUILDLOG.md/DECISIONLOG.md. **This tree's own image still needs its
own rebuild + smoketest pass** to confirm parity — not yet done, same
deferred status as the rest of this session's work here.

No GitHub issue yet. Comes after Guile deliberately — same Lisp-family,
REPL-first philosophy, worth doing back to back (though Racket's own Doom
module turns out to use `racket-mode`'s own REPL machinery, not Geiser —
correcting this section's earlier assumption, see below). Rash is a
`#lang rash` shell-scripting DSL built directly on Racket, chosen over
`scsh` (confirmed dormant — last stable release 2006, ~20 years without
active maintenance, fails this project's own "boring, reproducible,
actively-maintained dependency" standard, see AGENTS.md) as the actual
systems-scripting answer in this family.

**Real gap to weigh before starting, not glossed over:** `racket-rash`
(willghatch/racket-rash — confirmed directly against
pkgs.racket-lang.org/package/rash that this, not the unrelated
`cesquivias/rash` or the Rust-based `rash-sh/rash`, is what `raco pkg
install rash` actually resolves to) last pushed 2024-01-29 — about 2.5
years stale as of this writing, 35 open issues, not archived. Nowhere
near scsh's 20-year dormancy, and its own docs describe it as "largely
stable" with only some parts marked unstable, but this is still a real
question against this project's own maintenance standard, not a clean
pass — there's no better alternative for "shell DSL in Racket" (scsh
already ruled out), so the honest framing is "accept this tradeoff,"
not "no tradeoff exists." Flag for an explicit go/no-go before
implementing rather than proceeding silently.

**Doom's `:lang racket` module already exists** at the pinned commit
(confirmed directly: `modules/lang/racket/{config,packages,README.org}`
all present) — corrects this section's earlier "unconfirmed" caveat.
Key findings from its actual source:
- Package: `racket-mode` (Greg Hendershott's), pinned by Doom itself —
  no separate `(package! racket-mode)` needed in this project's own
  `packages.el`.
- `+lsp` flag: requires `:tools lsp` (already enabled in this image)
  plus a langserver on PATH — Doom's own README names
  `racket-langserver` (jeapostrophe/racket-langserver) by name.
  Confirmed still active (updates through Feb 2026, compatible with
  Racket 7.6–9.2).
- Doom's own `config.el` already wires a *rich* localleader map (run,
  test, expand-macro variants, send region/definition/last-sexp to the
  REPL, visit-definition, docs, logger, profiler, unicode input,
  paren-shape cycling) plus REPL/lookup handlers and a formatter
  (`raco fmt`, via the `fmt` package + this project's own `:editor
  format` module, already enabled) — unlike Nushell/TOML/Fish/
  Assembly, which all needed a project-authored `{lang}-config.el`/
  `{lang}-keybindings.el` from scratch, Racket's Doom module is
  actively-enough-built-out that **no new elisp file may be needed at
  all**, just the `init.el` flag below. Confirm this live before
  assuming zero elisp work, though — Doom's own README admits "this
  module needs a maintainer" (no active owner, even if the code itself
  still works).
- `.rkt` is the only extension Doom's module wires by default (plus
  `.scrbl`/`.rhm` behind an opt-in `+hash-lang` flag, deliberately left
  off for this project's initial scope — Scribble/Rhombus aren't part
  of this ask, revisit if wanted later). This also answers Rash's own
  file-extension question: `willghatch/racket-rash`'s own demo scripts
  all use plain `.rkt` (confirmed directly against its repo, e.g.
  `rash-demos/rash/demo/rc17.rkt`) with a `#lang rash` line inside, not
  a separate extension — Racket's `#lang` mechanism is file-extension-
  agnostic, so no additional `auto-mode-alist` entry is needed for Rash
  specifically.

**Racket install: prefer the official installer over apt, matching this
project's general bias** (rustup over apt for Rust, pinned binary
releases over apt for Nu/ruff/stylua/lua-language-server). Confirmed
live via a throwaway `ubuntu:26.04`/`ubuntu:24.04` container: apt ships
Racket 8.18 (26.04, resolute) / 8.10 (24.04, noble) against the actual
current stable release, 9.2 (May 2026) — multiple minor versions
behind, the same "apt is stale" pattern already hit with
TypeScript/rbs/cmake-language-server elsewhere in this file. Both
`racket-minimal-9.2-{arch}-linux-buster-cs.sh` self-extracting
installers exist for aarch64 and x86_64
(mirror.racket-lang.org/installers/9.2/) — "minimal" over the full
`racket-9.2-...` variant, mirroring how Doom's own README recommends
`racket-minimal` on Arch "for fewer dependencies." SHA256 hashes are
published inline per-file on mirror.racket-lang.org/releases/9.2/ (no
separate SHA256SUMS file) — capture fresh at implementation time
rather than trusting any previously-recorded hash, same as every other
checksum in this file.

**Dockerfile:**
- Download + verify + run `racket-minimal-9.2-{aarch64,x86_64}-linux-buster-cs.sh`
  (self-extracting installer — check its own `--help` for the exact
  non-interactive invocation before scripting it, matching the care
  already taken with Guix's own non-interactive-install research; don't
  assume a flag shape without checking)
- `raco pkg install racket-langserver rash fmt` once Racket itself is on
  PATH — rides on Racket's own package manager, no separate toolchain,
  mirrors how `guix archive --authorize`/`rustup component add` layer
  on top of their own base installs

**init.el:**
- Add `(racket +lsp)` to `:lang`, between `(python ...)` and `(ruby
  +lsp)` (alphabetical, matching this file's existing ordering)

**config.el / packages.el:**
- Likely nothing — verify live first (see the "no new elisp file may be
  needed at all" finding above) before authoring anything

**Verify:** Open a `.rkt` file with `#lang racket`; confirm `racket-mode`
activates, `racket-langserver` connects, the REPL starts via `SPC m r`,
and `raco fmt` formats via `:editor format`'s existing on-save wiring.
Open a second `.rkt` file with `#lang rash` instead; confirm the same
mode activates and check specifically how well `racket-langserver`'s
analysis holds up against a non-core `#lang` (its own docs describe it
working via DrRacket's public API, which is #lang-generic in principle
but unverified in practice for Rash specifically — don't assume parity
with plain Racket without checking). Run `racket --version` (expect
9.2) and confirm `rash`/`fmt` are `raco pkg show`-visible inside the
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

## Step 11.7: Haskell — scope decision, not yet scheduled

No GitHub issue yet. Not part of the current Racket+Rash → Zig →
Chez/Gambit/Gerbil integration order — raised during Racket/systems-Lisp
research as a side question ("is Haskell a systems language for this
project's purposes"), answered with a scope decision rather than an
implementation plan.

**Decision:** If Haskell is added to `systems-ide` at all, it gets
syntax-only highlighting (`haskell-mode` or tree-sitter, no LSP). Full
LSP/debugging (Haskell Language Server) is explicitly **not** planned
for `systems-ide` — it would instead go into its own dedicated,
refreshed IDE image, matching this repo's existing pattern of separate
per-language IDE directories for languages that need a heavier or more
specialized setup than the polyglot systems-ide gives them (Mercury,
Python, Scala all already have their own IDE dirs rather than being
folded into a shared image). A stale `29.2/ubuntu/22.04/x86_64/
haskell-ide/` already exists in this repo and could be the starting
point for a modern 30.2 version, whenever this is picked up.

**Why not just add HLS here like every other `+lsp` language:** Josiah
has had Haskell fully working in a past Doom config before and had it
"inexplicably break" with no root cause ever found — a real, painful,
unresolved history specific to Haskell tooling in Emacs, not
hypothetical caution the way (for instance) format-on-save's Lisp-family
caution is (see BUILDLOG.md/DECISIONLOG.md's `+onsave` notes). HLS is
also a heavier, more failure-prone piece of tooling than this image's
other LSP servers (multi-package cabal/stack project resolution, GHC
version coupling), which argues for giving it its own isolated,
purpose-built image rather than folding it into the shared systems-ide
polyglot image where a break is harder to isolate and rebuild around.

**Verify (whenever this is picked up):** Before doing anything else,
decide syntax-only vs. reviving `haskell-ide` as a separate build — this
step should not turn into ad-hoc HLS wiring inside `systems-ide` without
that decision being revisited first.

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

## ~~Step 13: Assembly~~ — [#13](https://github.com/josiah14-automation-engineering/docker-emacs/issues/13) ✓ COMPLETE

**Upgraded beyond the original syntax-only scope**: research turned up
`asm-lsp` (bergercookie/asm-lsp, Rust), a real language server (hover,
completion, signature help, goto-definition, references for GAS/NASM/
x86/x86_64/ARM/RISCV assembly, diagnostics via invoking gcc/clang
directly) with a built-in `lsp-mode` client (`clients/lsp-asm.el`) that
already activates for stock `asm-mode` — no manual `lsp-register-client`
needed, just an explicit `(require 'lsp-asm)` inside `(after! lsp-mode
...)` the same shape `nu-config.el` already established for lsp-nushell.

No Doom `:lang asm` module exists (confirmed against the pinned Doom
commit's `modules/lang/` tree — doomemacs has never shipped one), and
none was needed: `asm-mode` ships built into Emacs core with `.s`/`.S`/
`.asm` already in the default `auto-mode-alist` (confirmed live via
`emacs -Q --batch`). New `asm-config.el` just hooks `lsp!` onto
`asm-mode-local-vars-hook` and forces the `lsp-asm` require.

**Dockerfile (per-tree divergence, not a copy-paste):** aarch64 has no
Linux/aarch64 prebuilt `asm-lsp` release (confirmed against the actual
GitHub release assets — only `aarch64-apple-darwin`, `x86_64-apple-
darwin`, `x86_64-unknown-linux-gnu`), so it's installed via `cargo
install asm-lsp --locked --version 0.10.1` after the Rust step — which
needed `pkg-config`/`libssl-dev` added to the apt list too (confirmed
live: without them, the build fails on `openssl-sys` with "Could not
find directory of OpenSSL installation"). x86_64 *does* have a
published Linux binary, so that tree uses the prebuilt-tarball pattern
instead (matching ruff/stylua), with no Rust-toolchain coupling and no
extra apt packages needed.

No keybindings file — no formatter or build/run/test analog exists for
generic assembly, so there was nothing to bind beyond the global LSP
keys `lsp-mode` already provides for any active buffer.

---

## ~~Step 14: Syntax-only batch~~ — [#14](https://github.com/josiah14-automation-engineering/docker-emacs/issues/14) ✓ COMPLETE (Fish upgraded, Perl and Assembly split out)

**Fish upgraded beyond syntax-only, same reasoning as Assembly above**:
`fish-lsp` (ndonfris/fish-lsp, npm) is a real language server
(completion, hover, diagnostics) for fish scripts, but unlike asm-lsp,
`lsp-mode` ships no built-in client for it — registered by hand in new
`fish-config.el` (`lsp-register-client` + `lsp-stdio-connection '("fish-lsp"
"start")`, matching the shape planned for TOML). `fish-mode`
(wwwjfy/emacs-fish, `packages.el`) self-registers `.fish`/the `fish`
interpreter shebang via its own `;;;###autoload` cookies — no manual
`auto-mode-alist` wiring needed. Formatting needed no override either:
apheleia already defaults `fish-mode` to its own `fish-indent` formatter
(confirmed directly from `apheleia-formatters.el`). New
`fish-keybindings.el` binds `SPC m f` to `apheleia-format-buffer`,
matching every other full-tier language.

**Perl stays deliberately syntax-only** (Josiah: "I hate Perl, code in
it is usually a mess, I want to discourage Perl use") — no LSP, no
keybindings file, no Dockerfile change at all: `perl` 5.40.1 is already
a transitive apt dependency of something else in the image (confirmed
live — present with zero explicit `perl` package anywhere in the apt
list), and `perl-mode` + the `.pl`/`.pm` → `perl-mode` mapping both ship
built into Emacs core by default (confirmed live via `emacs -Q
--batch`). Nothing to add.

Assembly split out into its own completed step above rather than
staying folded into this batch, once it turned out to warrant full LSP
too.

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
