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

## ~~Step 8: Zig~~ ✓ COMPLETE (aarch64-verified, x86_64 build-untested) — [#7](https://github.com/josiah14-automation-engineering/docker-emacs/issues/7)

**Implemented and verified live end-to-end** (2026-07-24): `zig-mode`
activates, `zls` connects and correctly serves hover, goto-definition
(cross-file, `main.zig` → `counter.zig`), find-references, and rename
(all 4 occurrences across both files) — full details plus one corrected
finding in `flight-tests/zig/zig-flight-test.md`. Diagnostics work for
both syntax and semantic errors, but not via the mechanism this section
originally assumed: `flycheck-get-checker-for-buffer` reports `lsp`, not
Doom's manually-registered `zig` (`ast-check`) checker — the same
checker-priority-contest shape already seen with ruby-lsp-ls/rubocop-ls,
just never previously hit for a syntax-only checker vs. an LSP one. zls's
diagnostics cover semantics fully (confirmed with both a missing-semicolon
syntax error and an unused-local semantic error), so the `ast-check`-only
limitation flagged below turned out not to matter in practice.

The debugger cycle (the two gaps flagged below) is fully verified live:
`+dape-zig-program` correctly falls back to the buffer's own basename
before any build exists, then correctly resolves
`zig-out/bin/flight-test` after a real `zig build`; `+dape-resolve-cwd`
resolves the `build.zig` root throughout. A real breakpoint/continue/
step/inspect/completion cycle through `lldb-dap` confirmed `n: 0` → `n:
1` at the right lines, and the program printed its full expected output
and exited 0. `zig-run`/`zig-test-buffer` both turned out to run directly
against the buffer's file (`zig run`/`zig test <file>`), not through
`build.zig` at all — correcting this section's `zig build run` guess
below. `zig fmt` format-on-save (apheleia's own built-in default) also
confirmed live. One binding (`SPC c a`, code actions) is not independently
verified — a raw, incorrectly-formed `codeAction` LSP request hung zls
and froze the single-threaded Emacs session entirely (recovered by
relaunching the container, not by any in-session recovery — see the
flight-test doc). Full smoketest: 100/100 on aarch64. x86_64 tree got the
identical source changes mirrored over but was not rebuilt/tested this
session, same status as Racket's/Guile's own x86_64 gap.

Also added this session, following the exact same DRY/decoupling
discipline the elisp style guide calls for: `+dape--first-executable`, a
new private helper in `dape-config.el` shared by `+dape-cmake-program`
and the new `+dape-zig-program` (previously duplicated inline), and the
new zig-mode `modes` fix for lldb-dap/lldb-vscode is its own dedicated
`dolist`, matching this file's established one-loop-per-concern shape
(same as the `:disableASLR`/`:stopOnEntry` loops) rather than being
folded into the existing gdb/lldb-dap/lldb-vscode `:program` loop.

<details>
<summary>Original planning notes (superseded by the above, kept for context)</summary>

**Originally just a stub, not started**: `zig-keybindings.el` exists but is an
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

</details>

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

## ~~Step 11: Guile / Scheme~~ — [#11](https://github.com/josiah14-automation-engineering/docker-emacs/issues/11) ✓ COMPLETE

Uses Geiser (REPL integration) rather than LSP — the correct Emacs-idiomatic
approach for interactive Lisp development. Guile earns full-tier support
specifically because it's the implementation language of GNU Guix (the
Nix-equivalent in the Scheme world), not just general GNU-ecosystem affinity.

**Verified:** full 78-test smoketest suite passing at 76/78 (the two
failures — `vcpkg` version, `.h` file mode — are pre-existing and
unrelated). Guile's own tests (version, `.scm` → `scheme-mode`,
`flycheck-guile`, localleader format-buffer) all pass. Guix package
management is also wired in and self-contained inside the container
(`guix-daemon` runs in-container, started at container startup) — see
BUILDLOG.md/DECISIONLOG.md 2026-07-21 for the full story, including a
latent `polyglot-keybindings.el` bug found and fixed along the way that
had been silently breaking every language's localleader keybindings.

**Architecture decision: Guile is sourced from a standalone `guix-source`
image, not a plain apt install.** Same pattern as Step 3's Nix — Ubuntu's
apt `guile-3.0` and Guix's own bundled Guile only match by version
coincidence (Ubuntu freezes at release time; Guix keeps moving), and the
real intent is working with Guix's own package/channel definitions through
Geiser later, which needs Guix's own Guile module load path. Verified live
that no `guix-daemon` is needed to get a working `guile` out of the tarball
at all: Guix is itself implemented in Guile, so a full Guile closure is
already a transitive dependency of the `guix` package in the store — it's
just not symlinked into `guix`'s own profile `bin/` by default. See
`30.2/ubuntu/*/guix/` (both trees) and DECISIONLOG.md for the full
reasoning trail, including the reversed initial recommendation.

**Dockerfile:**
- `FROM josiah14/guix:1.5.0-ubuntu-{24.04,26.04} AS guix-source`
- `COPY --from=guix-source /gnu /gnu` and `/var/guix /var/guix`
- Symlink `guix`/`guile`/`guild`/`guile-config` into
  `~/.local/bin` (already on `PATH`), discovering the exact
  content-addressed store paths at build time rather than hardcoding them

**init.el:**
- Add `(scheme +guile)` to `:lang`, between `(rust +lsp)` and `(sh +lsp)`

**config.el:**
- Add `(load! "guile-keybindings")` — no separate `guile-config.el`, no
  `packages.el` entry needed: Doom's own `lang/scheme/config.el` already
  wires `set-lookup-handlers!`, `set-repl-handler!`, `flycheck-guile`,
  and an extensive localleader map with zero extra config

**Verify:** Open a `.scm` file; confirm `scheme-mode` + `flycheck-guile`
activate. Run `guile --version` inside the container. `SPC m '` toggles a
Geiser REPL.

---

## ~~Step 11.5: Racket + Rash~~ ✓ COMPLETE (aarch64-verified, x86_64 build-untested)

**Both Racket and Rash implemented and verified live** (2026-07-23):
`racket-mode` activates for both `#lang racket` and `#lang rash` files
(same `.rkt` extension), `racket-langserver` connects to both (1732 real
completions in the rash file, including rash-specific bindings — the
"does racket-langserver's analysis hold up for a non-core #lang" question
below is answered yes), the REPL runs correctly, and `raco fmt`
format-on-save works end-to-end. Rash's go/no-go (flagged below) was
answered explicitly: implement it, per Josiah's call that the maintainer
still actively uses it day-to-day, unlike scsh's genuine 20-year
abandonment. Zero new elisp files needed — Doom's own `lang/racket/
config.el` was already fully built out, same shape as Guile's own
`scheme` module. Full details, plus two real non-obvious findings
(apheleia's lazy engine-load affecting first-save-of-a-session for any
Doom-customized formatter, and Racket's own localleader `f` binding
colliding with the generic format keybinding) in BUILDLOG.md/
DECISIONLOG.md. Full smoketest: 94/94 on aarch64. x86_64 tree got the
identical source changes mirrored over but was not rebuilt/tested this
session — deferred to the batch x86_64 pass already planned, same status
as Guile's own x86_64 gap.

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

## ~~Step 11.7: Haskell~~ ✓ COMPLETE (aarch64-verified, x86_64 build-untested)

**Implemented and verified live** (2026-07-24), exactly per the scope
decision below: a bare `(haskell)` line in `init.el` with no `+lsp`/
`+tree-sitter` flags — confirmed directly against Doom's own
`lang/haskell/packages.el` that this installs only `haskell-mode` (no
`lsp-haskell`, no `haskell-ts-mode` package even gets pulled in without
the flags). Zero config.el/packages.el changes needed. Smoketest confirms
`.hs` files activate `haskell-mode`; fixture is an XMonad-config-shaped
snippet (not a generic "hi" print like most other fixtures) since XMonad
configs are this feature's actual motivating use case, per the "Not a
factor" note below.

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

## Step 11.8: Chez / Gambit / Gerbil (Systems-Programming Schemes)

Continues the Lisp-family, REPL-first track started with Guile and Racket
(Step 11 / Step 11.5) — these three are the "systems-programming" Schemes
raised as the ask that follows Zig, distinct from Guile (GNU/Guix's own
implementation language) and Racket, both already done.

No GitHub issue yet. Research was started but interrupted before any
Dockerfile/init.el work began — nothing for these three is implemented.
The notes below are what's confirmed so far; several real go/no-go
decisions are flagged and should be settled before writing any Dockerfile
lines, same standard as Rash's own flagged tradeoff under Step 11.5.

**Doom module support (confirmed against `lang/scheme/config.el` at the
pinned commit):**
- `+chez` and `+gambit` flags both exist on `:lang scheme` alongside the
  `+guile` flag already in use — verify exactly what each wires (REPL
  handler, flycheck, localleader) before assuming parity with Guile's
  own zero-extra-elisp outcome.
- Gerbil is **not** one of `scheme`'s flags — it's its own dialect/
  toolchain layered on top of Gambit, not a Geiser backend. It likely
  needs a project-authored `gerbil-config.el`/`gerbil-keybindings.el`
  from scratch, the same shape Nushell/TOML/Fish/Assembly needed,
  unlike Guile/Racket. Confirm live rather than assuming this.

**Packaging — real gaps found, not yet resolved:**
- **Chez**: apt's `chezscheme` is stale — 10.0.0 on 26.04 (resolute),
  9.5.8 on 24.04 (noble), vs upstream 10.4.1. Same "apt lags upstream"
  pattern already hit with Racket/TypeScript/rbs/cmake-language-server
  elsewhere in this file. Racket's own fix (official installer, fresh
  SHA256 captured at implementation time, over apt) is the likely
  template — but Chez Scheme's own release process (source build vs. a
  bootstrap-file-based release) hasn't been checked yet. **Go/no-go
  needed:** accept the stale apt version, or take on a source build.
- **Gambit**: apt's package name is `gambc`, not `gambit` (confirmed),
  currently 4.9.3 — still needs a check against Gambit's actual current
  upstream release before treating apt as good enough here (unlike
  Chez, this one hasn't been confirmed stale, only that the package
  name differs from what you'd guess).
- **Gerbil**: no apt package, and its GitHub Releases carry no binary
  assets — real binaries appear to live via the `gerbil/gerbil` Docker
  Hub image (has `amd64`/`arm64` tags) or a `git.cons.io` mirror,
  neither confirmed in depth yet. Since Gerbil builds on top of Gambit,
  a source build against this image's own `gambc` install may be
  simplest — untested assumption. **Go/no-go needed:** multi-stage
  `COPY --from=` a Docker image (mirrors Guile's own `guix-source`
  pattern under Step 11) vs. building from source in-Dockerfile.

**Before starting:** settle both go/no-go questions above explicitly
rather than picking silently, same standard as Rash. Then follow the
established per-language cycle (Dockerfile → `init.el` flags/new elisp
if Gerbil needs it → bats smoketest → GUI functional verification, not
just bats → ROADMAP/BUILDLOG/DECISIONLOG updates) — and check whether a
debugger applies at all here first: every Lisp-family language done so
far (Guile, Racket) uses its own REPL (Geiser / racket-mode) rather than
`dape`, so `dape-config.el` changes are likely out of scope unless
something about Chez/Gambit/Gerbil specifically needs them.

**Verify:** `chez --version` / `gsi --version` / whatever Gerbil's own
version-check invocation turns out to be, all inside the container.
Open one file per dialect and confirm the right major mode + REPL
handler activate. Same aarch64-first, x86_64-mirror-only convention as
every other step this batch.

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

## Step 15: Nim

Not yet researched in depth — this is a backlog placeholder, not a
verified plan; confirm everything below live before writing any
Dockerfile lines, same standard as every other step in this file.

No Doom `:lang nim` module is believed to exist (unconfirmed) — likely
needs the same project-authored `packages.el`/`nim-config.el` treatment
as TOML (Step 12), not a Doom module flag. `nim-mode` (MELPA) is the
likely major mode. `nimlangserver` (nim-lang/langserver) is the actively
maintained LSP option, installed via `nimble` (Nim's own package
manager) once the compiler itself is on `PATH` — installed either via
apt (check staleness first, same as everywhere else in this file) or
`choosenim` (Nim's official version manager, closer to rustup's role
for Rust). Debugger: Nim compiles to C then to a native binary, so a
dape `:program` resolver analogous to `+dape-zig-program` (Step 8) may
let this reuse gdb/lldb-dap rather than needing new debugger wiring —
check where `nim c` places its output by default (same-directory,
source-basename, unless a nimble project structure is in play).

**Verify:** Open a `.nim` file; confirm the major mode and (if wired)
`nimlangserver` activate. Run `nim --version` inside the container.

---

## Step 16: Odin

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

No Doom module, and no MELPA major mode confirmed yet either — check
for one before assuming a project-authored mode is needed from scratch
(unlike every other step in this file so far, which at minimum found an
existing major-mode package to lean on). OLS (DanielGavin/ols, "Odin
Language Server") is the LSP option — check whether it ships prebuilt
release binaries or needs a source build (Odin's own toolchain is
required to build OLS, since OLS is itself written in Odin). Debugger:
Odin compiles to native code via LLVM; likely another dape `:program`-
resolver candidate reusing gdb/lldb-dap, same reasoning as Nim above —
check `odin build`'s default output location/naming first.

**Verify:** Open a `.odin` file; confirm major mode + OLS. Run
`odin version` inside the container.

---

## Step 17: SBCL (Common Lisp)

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Doom is believed to have a `:lang common-lisp` module (SLY as the
REPL backend, mirroring Racket/Guile's own REPL-first shape) — this
needs the same due-diligence check already done for Guile/Racket
(Step 11 / Step 11.5) before assuming it's fully built out with zero
extra elisp: confirm against `lang/common-lisp/config.el` at this
project's pinned Doom commit rather than assuming parity. SBCL itself
is likely fine via apt (it's GCC-adjacent in how actively Debian/Ubuntu
track it, unlike the standalone-binary-release tools elsewhere in this
file) — check staleness anyway, same standard as everywhere else.
Completes the two-branch Lisp family this project has otherwise built
entirely out of Scheme (Guile, Racket, and Step 11.8's Chez/Gambit/
Gerbil) — Common Lisp is the other major historical branch, with its
own systems-programming pedigree (Lisp Machines).

**Verify:** Open a `.lisp` file; confirm `sly` connects to a running
SBCL REPL. Run `sbcl --version` inside the container.

---

## Step 18: Fortran

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

No Doom module expected. Emacs ships `f90-mode` built-in for free-form
modern Fortran (and `fortran-mode` for fixed-form/legacy source) --
check whether Doom's default Emacs build already auto-associates
`.f90`/`.f95`, or whether this needs an explicit `auto-mode-alist`
entry. LSP: `fortls` (fortran-language-server), installable via pip
(this image already has Python from Step 7's Python/Ruby/JS/TS tier).
Compiler: `gfortran` — part of GCC itself, already partially present
in this image via the C/C++ tier (Step 5/6), so apt staleness is less
of a concern than the standalone-binary-release tools elsewhere in
this file (it tracks whatever GCC version Ubuntu ships, already an
accepted tradeoff for gcc/g++). Debugger: gfortran output is
gdb-debuggable like any other GCC output — likely reuses dape's
existing gdb config directly, same as C/C++, probably needing zero new
`dape-config.el` work.

**Verify:** Open a `.f90` file; confirm major mode + `fortls`
completions. Run `gfortran --version` inside the container.

---

## Step 19: Ada

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

No Doom module expected. `ada-mode` (GNU project, MELPA) is the likely
major mode. LSP: Ada Language Server (`als`), bundled with GNAT
Community or installable via Alire (`alr`, Ada's official
toolchain/package manager — the modern equivalent of rustup for Rust,
worth checking as the primary install path before falling back to raw
apt `gnat`). Debugger: GNAT output is gdb-debuggable, likely another
direct reuse of dape's existing gdb config, same as Fortran above.

**Verify:** Open a `.adb`/`.ads` file; confirm major mode + `als`
completions. Run `gnat --version` (or `alr --version`) inside the
container.

---

## Step 20: D (syntax-only)

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

**Deliberately syntax-only -- an opinion signal, not a technical
limitation** (same mechanism as Perl, Step 14: "I hate Perl, code in it
is usually a mess, I want to discourage Perl use"). Josiah: dislikes
the Java/C++-style class-based OOP model D inherits, preferring
Smalltalk/Pharo-style object systems -- syntax-only tier here means
"usable if you must, not endorsed." Correction for the record: D
itself is modern and actively maintained (D Language Foundation,
DMD/LDC/GDC still shipping releases), not legacy/historical the way
Pascal (Step 21, below) genuinely is -- the tier placement is a
language-design opinion, not a judgment about D's maintenance state.
`d-mode` (Emacs D Mode, MELPA) is the existing major-mode package to
use, same shape as bare `(haskell)` in `init.el` -- likely needs the
same project-authored `packages.el` addition and nothing else, but
confirm no Doom module exists first.

**Verify:** Open a `.d` file; confirm `d-mode` activates and font-lock
engages.

---

## Step 21: Pascal (syntax-only)

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

**Deliberately syntax-only -- same opinion-signal reasoning as D
(Step 20) and Perl (Step 14)**, and here the "poor language choice"
read is the stronger of the two: Pascal is both genuinely legacy (Niklaus
Wirth, 1970) and its later Object Pascal/Delphi dialects carry the same
Java/C++-style class-based OOP model Josiah dislikes. `pascal-mode`
ships built into Emacs itself (unconfirmed this session -- verify
before assuming zero package work), which would make this the cheapest
addition in the whole file: no `packages.el` entry, no Dockerfile
change, no LSP, matching Perl's own zero-Dockerfile-change shape.

**Verify:** Open a `.pas` file; confirm `pascal-mode` activates and
font-lock engages.

---

## Step 22: EDN

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Not a Clojure dependency here -- Josiah uses EDN standalone as the
storylet/anchor data format for the PPN95 project (a Mercury codebase,
no Clojure toolchain involved). Syntax-only, but for a different reason
than Perl/D/Pascal's opinion-signal tier (Step 14/20/21): there's no
meaningful LSP ecosystem for standalone EDN files (existing Clojure LSP
servers, e.g. `clojure-lsp`, are Clojure-project-aware, not built for
bare data files) -- this is a real tooling gap, not a design objection
to the format. Check whether a small dedicated `edn-mode` package
already exists on MELPA before falling back to associating `.edn` with
`clojure-mode` purely for font-locking (EDN is a syntactic subset of
Clojure's reader syntax -- maps, vectors, keywords, sets, tagged
literals -- so this would work, but pulls in more Clojure-specific
tooling than actually needed for a bare-data use case).

**Verify:** Open a `.edn` file; confirm the major mode highlights
maps/vectors/keywords/tagged literals correctly.

---

## Step 23: Protobuf

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

The strongest candidate of this batch -- Protobuf (`.proto`) is a real
interface-definition language, not just a data format, and directly
relevant given this image already treats Docker/gRPC-adjacent systems
work as in-scope. `protobuf-mode` (MELPA) is the likely major mode. LSP
options need a real live comparison before picking one -- candidates
include `protols` (coder3101/protols) and tooling bundled with `buf`
(bufbuild/buf), neither confirmed this session. No debugger tier
expected -- a schema/config language, not an executable one, same shape
as TOML (Step 12).

**Verify:** Open a `.proto` file; confirm major mode + whichever LSP is
chosen provide real completions/diagnostics.

---

## Step 24: HCL

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Terraform's configuration language -- real infra-as-code relevance.
`hcl-mode` (MELPA) is the likely major mode. `terraform-ls`
(HashiCorp's own official language server) is the clear LSP choice,
mature and actively maintained. No debugger tier expected, same
reasoning as Protobuf/TOML above.

**Verify:** Open a `.tf` file; confirm major mode + `terraform-ls`
completions.

---

## Step 25: Jsonnet

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Part of the "programmable config" cluster (Jsonnet/CUE/Dhall below) --
a real language (functions, imports, local variables) layered over
JSON, most relevant for Kubernetes/cloud-infra config generation.
`jsonnet-mode` (MELPA) is the likely major mode. `jsonnet-language-server`
(grafana/jsonnet-language-server) is the LSP option. No debugger tier
expected.

**Verify:** Open a `.jsonnet` file; confirm major mode + LSP
completions.

---

## Step 26: CUE

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Same cluster as Jsonnet/Dhall -- a newer, increasingly popular
config/schema language (Kubernetes/API-schema use cases). Emacs
major-mode maturity is unconfirmed -- check before assuming a clean
MELPA package exists. The CUE CLI itself reportedly ships its own `cue
lsp` subcommand (unconfirmed this session) -- if true, this would be
the simplest LSP path of the whole batch, no separate LSP binary to
install/pin beyond the `cue` CLI already needed for the language
itself.

**Verify:** Open a `.cue` file; confirm major mode + `cue lsp` (or
whatever LSP is actually available) completions.

---

## Step 27: Dhall

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

Same cluster as Jsonnet/CUE, but more academically-flavored (a real
typed lambda calculus underneath) -- niche relative to the other two
but still a genuine language, not just data. `dhall-mode` (MELPA) is
the likely major mode. `dhall-lsp-server` (dhall-lang's own package) is
the LSP option. No debugger tier expected.

**Verify:** Open a `.dhall` file; confirm major mode + `dhall-lsp-server`
completions.

---

## Step 28: XML

Not yet researched in depth — backlog placeholder, confirm live before
implementing.

The weakest organic driver of this batch -- add only once something
concrete actually needs it (a `pom.xml`, an Ant build, etc.), not
speculatively. `nxml-mode` ships built into Emacs itself (zero package
cost). `lemminx` (Eclipse) is a mature, real LSP option.

**Verify:** Open a `.xml` file; confirm `nxml-mode` + `lemminx`
completions/validation.

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
