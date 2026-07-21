# Systems IDE Build Log
## Emacs 30.2 / Ubuntu 24.04 / x86_64

---

### Why "systems-ide" rather than "rust-ide" or "c-ide"?

The image covers C, C++, Rust, and Zig as primary languages with full IDE support,
plus a range of languages a systems programmer regularly encounters. "systems-ide"
names the role rather than a specific language, leaves room for future additions
(Zig was included from the start; the name would already be wrong as "rust-c-ide"),
and maps cleanly to the Systems track in the polyparadigm curriculum.

---

### Language stack decisions

The full language stack was determined through an explicit design conversation before
any files were created. The starting point was C, C++, and Rust as primary languages.
Josiah then added Zig ("let's add zig while we're at it") and explicitly ruled out
Ada ("I don't think I'll ever use Ada"). The remaining language decisions — what gets
full support vs. syntax-only, and which fringe languages to include — came out of a
structured review where Josiah confirmed or redirected each choice.

#### Full IDE support (LSP + debugger)

**C / C++**
- LSP: `clangd` (from apt). The best-supported C/C++ language server; works with
  both GCC and Clang-compiled projects via `compile_commands.json`.
- Compiler: both `gcc`/`g++` and `clang`/`clang++` in the image. Different projects
  expect different compilers; shipping both avoids having to choose.
- Debugger: `gdb` via dap-mode.

**Rust**
- Toolchain: `rustup` — installs to `~/.cargo` as the runtime user, same as local
  development. Gives clean access to `rust-analyzer` as a rustup component and lets
  you add targets and toolchains from inside a running container.
- LSP: `rust-analyzer` installed via `rustup component add rust-analyzer`. Also adds
  `rust-src` for accurate cross-library completion and go-to-definition.
- Debugger: `codelldb` — a DAP server backed by lldb. Better Rust support than
  plain gdb; handles Rust's data representations (enums, `Option`, `Result`) correctly
  in the debugger UI.

**Zig**
- Toolchain: pre-built binary tarball from ziglang.org. Zig ships self-contained
  releases with no system dependencies; the tarball extracts to a directory that
  goes directly on PATH. Isolated into its own `zig-build` stage so build tools
  don't leak into the final image.
- LSP: `zls` (Zig Language Server). Unlike Mercury, a working LSP exists for Zig
  with good coverage of completions, go-to-definition, and hover. Must be pinned to
  the same version as the Zig toolchain — they are tightly coupled.
- Debugger: `lldb` via `codelldb` (same DAP server as Rust).

**Shell (bash/zsh/sh)**
- LSP: `bash-language-server` via npm. Covers completions, hover, and basic
  diagnostics for POSIX shell and bash. Shell is the connective tissue of systems
  programming; full IDE support here pays off daily.

**Lua**
- LSP: `lua-language-server` (sumneko). Pre-built binary from GitHub releases.
  Lua is embedded in too many systems-adjacent tools to treat as syntax-only:
  nginx config, Redis scripting, Neovim config, embedded firmware, OpenWRT.
  Full IDE support makes reading and editing those configs significantly more productive.

**Nix**
- LSP: `nil` (Nix language server). Pre-built binary from GitHub releases.
  Only the LSP binary is installed — not the Nix daemon or /nix store. `nil` does
  static analysis of Nix expressions without evaluating them, so it works correctly
  for syntax checking, go-to-definition within a file, and hover without a running
  Nix installation. Mount a nix store from the host if you need evaluation.

**Guile / Scheme**
- No LSP server exists for Guile with meaningful coverage. The Emacs-idiomatic
  approach is **Geiser** — a REPL integration package analogous to Slime for Common
  Lisp. Geiser provides send-to-REPL, interactive evaluation, documentation lookup,
  and completion driven by a live Guile process. This is richer than what a static
  LSP would provide for a Lisp, not a downgrade. Doom's `:lang (scheme +guile)`
  enables Geiser with Guile support. Josiah confirmed the Geiser route after the
  tradeoff was explained — specifically that the absence of an LSP is not a gap
  but the correct Emacs-idiomatic answer for interactive Lisp development.
- Rationale for inclusion: GUIX uses Guile Scheme directly for all package
  definitions and system configuration. GNU tools (gdb, guile itself) use Guile as
  their extension language. A systems programmer working with GNU infrastructure
  will encounter Guile.

**CMake**
- LSP: `cmake-language-server` via pip. C/C++ projects almost universally use CMake;
  treating it as syntax-only would make editing `CMakeLists.txt` substantially worse.

**TOML**
- LSP: `taplo` (TOML language server). Pre-built binary from GitHub releases.
  TOML is Rust's native config format (`Cargo.toml`) and increasingly common in
  systems tooling configs. Taplo provides schema-aware completion and formatting.
  Doom has no `:lang toml` module; `toml-mode` and taplo wiring are added via
  `packages.el` and `config.el`.

#### Syntax highlighting only (no LSP, no debugger)

The distinction: these languages appear in systems environments but the image is not
a primary development environment for them. A systems engineer reads them, edits them
occasionally, but doesn't need the full toolchain overhead.

The syntax-only category was Josiah's own framing — he raised the question of whether
to include Python and Go "without LSP support, anticipating that some small system
scripts in those languages would be encountered by a systems programming engineer."
This is the right mental model: distinguish between languages you develop in and
languages you read. He extended the same reasoning to Ruby, Perl, Fish, and Assembly
without prompting.

- **Python** — glue scripts, build tooling, test harnesses. Syntax only; no pyright/pylsp.
- **Go** — many systems tools are written in Go. Syntax only; no gopls.
- **Ruby** — Chef, Puppet, Vagrant, Homebrew. Syntax only; no solargraph.
- **Perl** — legacy sysadmin scripts; still present in older Unix environments. Syntax only.
- **Fish** — alternative shell; encountered in dotfiles and tooling. `fish-mode` package.
- **Assembly** — x86 and ARM asm appear in compiler output, embedded work, and hot-path
  inspection. `:lang asm` with nasm support.

Ruby, Perl, and Fish were flagged as lower-confidence inclusions in the review.
Josiah pushed to include them anyway, reasoning that baking in syntax highlighting is
cheap and anyone needing more can extend the image definition. That's the correct
call: the cost is a few lines in `init.el` and a package or two; the benefit is that
any file you open in these languages reads cleanly rather than as plain text.

The full support vs. syntax-only split for CMake, Lua, Nix, Shell, Guile, and TOML
was Josiah's explicit decision: "I say full support for CMAKE, Lua, Nix, Shell,
Guile, TOML." This call was made after reviewing the available tooling for each and
confirming there were viable LSP servers or equivalent (Geiser for Guile).

---

### Dockerfile stage structure

Three stages:

1. **`emacs-build`** — pulls the pre-built Emacs 30.2 dev image. Same as mercury-ide.

2. **`zig-build`** — downloads and verifies the Zig toolchain tarball and the ZLS
   binary. Isolated into its own stage so curl, xz-utils, and the Zig download
   infrastructure don't land in the final image. Only `/usr/local/zig` is copied
   forward. ZLS binary lives alongside the Zig compiler in the same directory.

3. **`final`** — Ubuntu 24.04 base. Copies Emacs from `emacs-build` and Zig+ZLS
   from `zig-build`. Installs apt dependencies, LSP servers (pip/npm/binary), and
   sets up the user. Rustup runs as the runtime user in this stage since rustup is
   a user-local install.

Unlike Mercury's `mercury-build` stage, the Zig stage doesn't compile anything —
Zig ships pre-built binaries for all platforms. The stage exists purely to isolate
the download tooling, not to contain build dependencies.

---

### 2026-05-06 — Scaffolding created

Initial scaffold files created: `Dockerfile`, `build.sh`, `init.el`, `config.el`,
`packages.el`. The first pass included the full language stack already wired into
init.el and the Dockerfile. After review, Josiah directed a reset to bare Doom —
no language modules yet, cross-language tooling (LSP framework, debugger, magit,
flycheck, company, vertico) only. The rationale: add one language at a time so
each addition can be built, tested, and understood in isolation. The full language
roadmap is captured in `TODO.md` rather than pre-emptively implemented.

Josiah also set the collaboration expectation for this IDE going forward: each
language addition should be discussed before any code is written, and larger
elisp sections (keybindings, mode configuration) he intends to author himself.
The IDE build is a practice, not a deliverable to be generated and handed over.

Per that structure, skeleton keybinding files were created for every full-support
language at scaffolding time: `sh-keybindings.el`, `c-keybindings.el`,
`rust-keybindings.el`, `zig-keybindings.el`, `cmake-keybindings.el`,
`lua-keybindings.el`, `nix-keybindings.el`, `guile-keybindings.el`. Each file
is empty except for a header comment. The files are COPY'd into the image now so
the structure is in place; each is activated via `(load! "<name>-keybindings")` in
`config.el` when its language step is worked through. No `load!` calls are present
in config.el yet — they are added as part of each step.

No build has been attempted yet.

---

### 2026-05-06 — Dockerfile apt list cleanup; Powerline commit parameterized

The `apt-get install` block was reformatted: each of the 63 packages moved to its
own line, and grouped by role using inline backtick-subshell comment labels
(`` `# --- group ---` ``). Groups: system utilities, cli live troubleshooting tools,
native elisp compilation, emacs runtime (audio / display / image / text+encoding /
misc), fonts. Packages alphabetized within each group.

Josiah reviewed the labels and sharpened two: "cli tools" became "cli live
troubleshooting tools" to make the intent of that group explicit, and "native
compilation" became "native elisp compilation" to distinguish it from toolchain
compilation steps that appear elsewhere in the file. Both corrections reflect
reading the groupings critically rather than accepting the first pass.

The Powerline fonts git commit hash was extracted from the `git checkout` step and
promoted to a named `POWERLINE_FONTS_COMMIT` ARG in the header block, consistent
with the `DOOM_COMMIT` pattern.

Josiah then asked whether the source-code-pro sha512 should be parameterized by
the same logic. The answer is no: `POWERLINE_FONTS_COMMIT` controls *what* is
fetched and is a legitimate build-time variable. The sha512 is an integrity check
on a specific artifact — parameterizing it would allow a `--build-arg` override to
silently bypass the check. The right time to promote it to an ARG is if the
download URL or tag is also parameterized, so that version and hash travel together
as a pair. Josiah accepted that distinction.

**Outstanding before first build attempt:**

1. **Pin Zig version and sha512.** Identify the current stable Zig release, fetch
   the sha512 for the Linux x86_64 tarball from ziglang.org/download, and set
   `ZIG_VERSION` and `ZIG_SHA512` in the Dockerfile.

2. **Pin ZLS version and sha512.** Must match ZIG_VERSION exactly. Fetch from
   https://github.com/zigtools/zls/releases. Verify the release asset URL pattern
   and checksum file format.

3. **Pin lua-language-server version and sha512.** Pre-built binary from
   https://github.com/LuaLS/lua-language-server/releases. Identify the Linux x86_64
   asset name pattern.

4. **Pin nil version and sha512.** Pre-built binary from
   https://github.com/oxalica/nil/releases.

5. **Pin taplo version and sha512.** Pre-built binary from
   https://github.com/tamasfe/taplo/releases. Identify the correct asset for
   Linux x86_64 (may be named `taplo-linux-x86_64`).

6. **Pin codelldb version and sha512.** Distributed as a `.vsix` from
   https://github.com/vadimcn/codelldb/releases. The vsix is a zip; extract
   `adapter/` to a stable path and point `dap-codelldb-extension-path` at it
   in `config.el`.

7. **Pin rustup installer sha256.** The rustup installer at `sh.rustup.rs` changes
   over time. Fetch the current installer, record its sha256, and add a verification
   step before piping to sh.

8. **Verify Doom module availability at pinned commit.** Confirm `:lang zig`,
   `:lang (scheme +guile)`, `:lang cmake`, and `:lang nix` exist at Doom commit
   `4e0dbb9`. If any are absent, either bump the Doom commit or add the package
   manually via `packages.el`.

9. **Wire DAP for Rust, Zig, and C/C++.** `config.el` has placeholder comments;
   fill in `dap-codelldb-extension-path` once codelldb is installed, and configure
   `dap-gdb-lldb` for C/C++.

10. **Generate straight.el lockfile.** After a successful first build, walk
    `~/.config/emacs/.local/straight/repos/` and generate `straight-versions.el`
    using the same approach as mercury-ide.

---

### 2026-05-06 — Step 1: Shell language support wired

Shell was chosen as the first language addition — highest priority per `TODO.md`
and the connective tissue of systems programming. The step expanded significantly
from the TODO stub once the full tooling picture was worked through.

#### bash-language-server

The language server is TypeScript compiled to JavaScript, distributed on npm, and
runs on Node. It is a thin LSP bridge: completions, hover, go-to-definition for
functions. The actual diagnostic intelligence comes from **shellcheck**, a separate
Haskell binary that is invoked as a subprocess. Without shellcheck on PATH,
the language server runs but diagnostics are silent. Both must be in the image.

Josiah asked whether bash-language-server could be native-compiled for better
performance. The answer is no in any meaningful sense — Node's V8 JIT-compiles
JavaScript at runtime but there is no AOT path to machine code for Node
applications. `deno compile` and Bun's `--compile` flag both package JS with
their respective engines (V8 and JavaScriptCore), not native code. For a
language server — a long-running process that starts once per session and warms
up through JIT after a few interactions — this is irrelevant in practice.

The alternative path (flycheck wired directly to shellcheck, bypassing the
language server entirely) was raised and discussed. It gives diagnostics without
the Node dependency. Josiah chose the full LSP path for the completions and
function navigation it adds on top of raw shellcheck.

**bash-language-server pinned to 5.6.0** (latest stable as of May 2026; released
April 2025, no newer release available).

#### Shellcheck argument tuning

`bash-language-server` exposes a `bashIde.shellcheckArguments` configuration
key, set in Emacs via `lsp-bash-shellcheck-arguments`. The tuning surface is
thin; the two flags worth setting:

- **`-x`** — follow `source` statements into other files. Without it, shellcheck
  treats sourced files as opaque and cannot check across file boundaries.
- **`-s bash`** — lock the target shell dialect so shellcheck does not flag
  bash-isms as POSIX portability warnings.

The idiomatic project-level approach is a `.shellcheckrc` file at the repo root;
`lsp-bash-shellcheck-arguments` sets the global default for files that lack one.

#### Zsh coverage

Josiah identified himself as a long-time oh-my-zsh user and directed that zsh
editing support be included — a scope expansion beyond the original Shell step.

A web search confirmed that **no mature zsh LSP server exists**. The
`bash-lsp/bash-language-server` issue #252 (open, unresolved) tracks the request
for zsh syntax support. shellcheck explicitly does not support zsh, which
eliminates the diagnostic backend that any zsh LSP would need. The situation is
unlikely to change without a new analysis engine being written from scratch.

`sh-mode` (built into Emacs) already handles zsh files — it is a multi-shell
mode that sets `sh-shell` to `'zsh` when it detects a zsh shebang. For dotfiles
(`.zshrc`, `.zshenv`, etc.) that carry no shebang, `sh-mode` has no way to
determine the shell and falls back to generic highlighting. The fix is a
lightweight derived mode:

```elisp
(define-derived-mode zsh-mode sh-mode "ZSH"
  (sh-set-shell "zsh"))
```

This ensures zsh syntax rules apply regardless of whether a shebang is present,
labels the modeline "ZSH", and inherits all `sh-mode` hooks. A separate
`zsh-mode` MELPA package does not exist in a maintained form; writing the three
lines directly is the equivalent.

Josiah also directed inclusion of **zshdb** — a gdb-like debugger for zsh
scripts. zshdb 1.1.4 was released March 2024 (maintenance mode, not abandoned).
Its Emacs integration is through **realgud**, not dap-mode — a separate debugger
framework invoked via `M-x realgud:zshdb`. zshdb support is built into realgud
(no separate package). realgud is pure Emacs Lisp; neither it nor zshdb
meaningfully affects container size.

#### Shell configuration extracted to shell.el

Josiah proposed extracting all shell-related configuration into a dedicated
`shell.el` rather than inlining it in `config.el`. This mirrors the keybinding
file pattern already established and keeps `config.el` as an index of `load!`
calls rather than implementation. The boundary:

- **`shell.el`** — `zsh-mode` derived mode definition, `auto-mode-alist`
  associations, `lsp-bash-shellcheck-arguments`
- **`sh-keybindings.el`** — keybindings and mode hooks (empty; authored when
  ready)

For the `auto-mode-alist` entries, the first proposal was to write out a full
`add-to-list` call per file extension pattern. Josiah countered with a functional
approach: curry `add-to-list` after `'auto-mode-alist` and fold over the list of
patterns. That instinct prompted a recommendation of `mapc` as the correct
Elisp tool — it applies a function to each element of a list for side effects and
discards the return values. `dolist` was also raised as the idiomatic Lisp
alternative: an explicit loop construct that needs no lambda wrapper and reads as
plain iteration. Josiah chose `dolist` for its syntactic cleanliness — the absence
of the lambda wrapper makes the intent obvious without requiring the reader to
know `mapc`.

File patterns registered to `zsh-mode`: `*.zsh`, `*.zsh-theme`, `*.plugin.zsh`,
`.zshrc`, `.zshenv`, `.zprofile`, `.zlogin`, `.zlogout`.

Josiah wrote `packages.el` and `shell.el` himself. He noted that writing even
small `(package! ...)` declarations himself helps internalize Doom's architecture.

#### Changes

**Dockerfile:**
- New apt group `# --- shell ide ---`: `nodejs`, `npm`, `shellcheck`, `zshdb`
- New `RUN npm install -g bash-language-server@5.6.0` step (runs as root, before
  user switch; installs to `/usr/local/bin`)
- `COPY shell.el` added alongside the keybinding file COPY block

**`init.el`:** `(sh +lsp)` added to `:lang`

**`shell.el`:** New file. `define-derived-mode zsh-mode`, `dolist` loop for
`auto-mode-alist`, `lsp-bash-shellcheck-arguments` set to `"-x -s bash"`.

**`packages.el`:** `(package! realgud)` — written by Josiah.

**`config.el`:** `(load! "shell")` and `(load! "sh-keybindings")` added under a
separator comment block.

No build attempted yet. `sh-keybindings.el` is empty and will remain so until
keybindings are authored.

---

### 2026-05-06 — shell.el expanded: bash-mode, ksh-mode, shellcheck flag revision, refactoring

#### Bash and ksh coverage

The shell step was extended beyond zsh to cover bash and ksh dotfiles explicitly.
The decision driver: `lsp-bash-shellcheck-arguments "-x -s bash"` overrides
shellcheck's shebang-based auto-detection globally. A ksh script with `#!/bin/ksh`
would be analyzed as bash, with ksh-specific syntax reported as errors. The fix
required reconsidering the `-s` flag before the derived-mode design could be
settled.

**`-s bash` dropped; `-x` retained.** Without `-s`, shellcheck reads the shebang
and uses the correct dialect per file. The tradeoff: dotfiles without shebangs
fall back to shellcheck's default (`sh` dialect), which would flag bash-specific
syntax in `.bashrc` as POSIX warnings. The mitigation is shellcheck's own
per-file annotation — `# shellcheck shell=bash` near the top of a dotfile — or a
user-level `.shellcheckrc`. This is more correct for a multi-shell IDE than
forcing bash globally.

`bash-mode` and `ksh-mode` derived modes were added parallel to `zsh-mode`, each
calling `sh-set-shell` with the appropriate shell. This is the Emacs-side fix —
correct syntax highlighting and indentation for dotfiles without shebangs.
Shellcheck's dialect is handled separately via shebang detection or per-file
annotations. The two concerns are independent.

A copy-paste bug was caught during this pass: the original ksh `dolist` block
registered patterns to `'zsh-mode` instead of `'ksh-mode`. Fixed as part of the
rewrite.

`.profile` was explicitly excluded from the ksh patterns — it is typically written
to be POSIX sh-compatible and shared across shells; mapping it to `ksh-mode` would
be inaccurate.

#### Refactoring: extract function, then outer loop

With three `dolist` blocks following the identical pattern — iterate patterns,
call `add-to-list 'auto-mode-alist` — Josiah identified the repetition and
proposed an extract-function refactoring. The extracted function:

```elisp
(defun register-shell-file-patterns (patterns mode)
  (dolist (file-extension-pattern patterns)
    (add-to-list 'auto-mode-alist (cons file-extension-pattern mode))))
```

After writing the three call sites, Josiah pushed further: replace the three
separate calls with a single loop over a data structure mapping each mode to its
patterns. The structure that makes this work is a list of lists — mode symbol as
`car`, pattern list as `cdr`:

```elisp
'((bash-mode "\\.bash\\'" "\\.bashrc\\'" ...)
  (zsh-mode  "\\.zsh\\'" ...)
  (ksh-mode  "\\.ksh\\'" ...))
```

`car` extracts the mode, `cdr` extracts the already-correct pattern list —
no reshaping needed before passing to `register-shell-file-patterns`. `dolist`
was chosen over `mapc` for the outer loop, consistent with the earlier preference:
no lambda wrapper, intent reads as plain iteration.

The commented-out superseded code was deleted rather than preserved. Rationale:
git history and editor undo both make the old code recoverable; dead commented
code is noise.

#### Final shape of shell.el

Three `define-derived-mode` blocks grouped at the top. One `defun`. One `dolist`
outer loop over the shell configuration data structure. `lsp-bash-shellcheck-arguments`
updated to `"-x"`.

**`shell.el`** updated: `bash-mode` and `ksh-mode` derived modes added;
`register-shell-file-patterns` function extracted; three `dolist` blocks collapsed
to one outer loop; `-s bash` dropped from shellcheck arguments.

---

### 2026-05-06 — sh-keybindings.el authored; shell step complete

`sh-keybindings.el` was written to close out the shell step. Bindings sit on
`sh-mode-map` and therefore apply to all derived modes (`bash-mode`, `zsh-mode`,
`ksh-mode`) without additional wiring.

The file opens with a reference comment block documenting the Doom/LSP defaults
already active in shell buffers — `g d` (go to definition), `g D` (find
references), `K` (hover), `] d` / `[ d` (next/prev diagnostic), `SPC c a` (code
actions), `SPC b c` (flycheck buffer from config.el global). The rationale:
one source of truth for discovering language-specific keybindings rather than
hunting through Doom's documentation.

Localleader bindings added under `SPC m`:

| Chord      | Description          | Function                                    |
|------------|----------------------|---------------------------------------------|
| `SPC m e e` | Execute region      | `sh-execute-region`                         |
| `SPC m e b` | Execute buffer      | `sh-execute-region` on `(point-min)`→`(point-max)` via `cmd!` |
| `SPC m r r` | Rename symbol       | `lsp-rename`                                |
| `SPC m d d` | Start debugger      | `realgud:zshdb`                             |
| `SPC m s s` | Switch shell dialect | `sh-set-shell`                              |

`cmd!` (Doom's macro for wrapping a form into an interactive command) used for
execute-buffer to avoid a named `defun` for a one-liner.

The debugger binding notes `realgud:bashdb` as the bash equivalent in a comment.
The dispatch gap (binding sits on `sh-mode-map`, invokes zshdb in all shell
buffers) is a known issue deferred to a future pass when `bashdb` is added to the
image.

**Shell step status: configuration complete. Build and verification pending.**

---

### 2026-05-13 — First build attempt; zshdb not in Ubuntu 24.04 apt repos

First build attempt surfaced `E: Unable to locate package zshdb`. The `zshdb` package exists in Ubuntu's universe repo up through focal (20.04) but is absent from noble (24.04). No PPA with 24.04 coverage was found.

**Resolution: install zshdb from source.** The upstream repo is `github.com/rocky/zshdb`. Build steps follow the standard autotools pattern: `./autogen.sh && ./configure && make && make install`.

**Dockerfile changes:**
- `ZSHDB_VERSION=1.1.4` ARG added to the header block (pinned to the latest release tag; to be hardened to a commit SHA once the build is confirmed clean)
- `zshdb` removed from the apt list
- `autoconf`, `automake`, and `zsh` added to the shell IDE apt group (`autoconf`/`automake` for the build; `zsh` required by zshdb's configure step)
- New `RUN` step added before the npm install: clone at tag, `autogen.sh`, `configure`, `make`, `make install`, cleanup
- `make` added to the shell IDE apt group (missing build dep surfaced by the build)

**Image built successfully.**

---

### 2026-05-13 — Shell step verified

Josiah ran the container and tested shell scripting support. All capabilities confirmed working:

- **LSP completions** — bash-language-server providing completions and hover docs
- **Context awareness** — local variables inside functions detected; parameter signatures surfaced on function calls
- **Unused variable detection** — shellcheck flagged unused `src` and `dest` when omitted
- **SC2155** — shellcheck correctly warned on combined `local dest=$(...)` declare-and-assign; fix is to separate the `local` declaration from the assignment
- **Source following** — `-x` flag working; shellcheck follows `source ./lib.sh` and resolves symbols defined in sourced files
- **Shell dialect detection** — bash-language-server detected the bash shebang automatically; LSP prompted for project import on first open

**Shell step status: complete.**

---

### 2026-05-13 — run.sh created

`run.sh` written for launching the GUI Emacs container. Key decisions:

- X11 forwarding via `-e DISPLAY`, `/tmp/.X11-unix` mount, and `--ipc host` (shared memory for clipboard)
- `~/Development/personal` mounted at the same path as the host, consistent with the FaradAI layout pattern
- `.gitconfig` mounted read-only
- `MARCH` ARG respected so the image tag matches the build target
- No resource limits — not necessary for a personal containerized code editor at this stage

---

### 2026-05-28 19:59 — Go and Nushell steps prioritized; scaffolding begun

#### Reprioritization

Go (Step 2) and Nushell (Step 3) were pulled ahead of C/C++/Rust/Zig in `TODO.md`.
The driver: the FaradAI CLI rewrite (#65) targets Go for the main binary and Nushell
for support scripts. Both toolchains need to be available in the systems-ide before
that migration work starts. All prior step numbers shifted down by two.

Go's entry in the syntax-only batch (now Step 14) was removed — full LSP supersedes
it.

#### Version pins

| Tool | Version | Hash |
|---|---|---|
| Go toolchain | 1.26.3 | SHA256 `2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556` |
| gopls | v0.22.0 | (installed via `go install`; integrity guaranteed by module proxy) |
| Nushell | 0.113.0 | SHA256 `6e94ee0035367c471b34dada57a735e55f5613d97ac3fa58c0ef241f22a12ede` |

Nushell musl binary — `nu-0.113.0-x86_64-unknown-linux-musl.tar.gz` — was chosen over the
glibc release for the same reason as always: statically linked, no libc version
dependency in the final image.

#### Nushell mode research

`nushell-mode` (`mrkkrp/nushell-mode` on MELPA) is syntax-highlighting only. It derives
from `prog-mode` via `define-derived-mode`; `nushell-mode-map` is auto-created but
currently empty. No LSP is built in. LSP is wired manually in `config.el` via
`lsp-register-client` pointing to `nu --lsp` (the built-in Nushell LSP server,
available since Nu 0.85). The `(sh +lsp)` module is unrelated — it covers
bash/zsh/sh/ksh only.

#### Elisp authorship boundary

During this step the collaboration boundary for elisp was restated and sharpened:

- **Josiah writes:** all `map!` keybinding calls, all `config.el` language additions
  (auto-mode-alist, lsp-register-client, hooks), any elisp config files analogous to
  `shell.el`
- **AI produces:** Dockerfile changes, `init.el` module flag additions (e.g.
  `(go +lsp)`), `packages.el` package declarations, keybinding file reference comment
  headers

This mirrors the pattern established at scaffolding (2026-05-06): writing even small
elisp declarations himself helps internalize Doom's architecture. The IDE build is a
practice, not a deliverable.

Concretely: `go-keybindings.el` and `nu-keybindings.el` were created with only the
default-bindings reference comment and `provide` — no `map!` calls. The `config.el`
additions for Nushell LSP registration and `auto-mode-alist` are Josiah's to write.

#### Changes made this session

**`TODO.md`:** Go inserted as Step 2, Nushell as Step 3; all prior steps renumbered.

**`init.el`:** `(go +lsp)` added to `:lang`.

**`packages.el`:** `(package! nushell-mode)` added.

**`go-keybindings.el`:** New file. Reference comment only; `(provide 'go-keybindings)`.

**`nu-keybindings.el`:** New file. Reference comment only; `(provide 'nu-keybindings)`.

**Dockerfile, `config.el`:** Pending — Josiah authors `config.el` additions; Dockerfile
changes (go-build stage, Nu binary download, gopls install, COPY additions) are AI's
to write and are next.

---

### 2026-05-28 20:09 — Decision: write Nushell as a proper Doom module; contribute upstream

Rather than wiring Nushell manually in `config.el`, the decision was made to write a
proper Doom module (`modules/lang/nushell/`) and offer it back to the Doom community.
No Doom-maintained Nushell module exists; `:lang scad` (PR #7566) confirms new language
modules are accepted (they land in a "modules backlog" milestone — slow review is
normal).

#### Research findings

**`nushell-mode`** (`mrkkrp/nushell-mode`, MELPA) — syntax highlighting only; derives
from `prog-mode`; no built-in LSP; auto-creates `nushell-mode-map`. File pattern:
`"\\.nu\\'"`.

**`nushell-ts-mode`** (`herbertjones/nushell-ts-mode`, MELPA) — tree-sitter mode; on
MELPA but less widely used (34 commits). Requires grammar from
`https://github.com/nushell/tree-sitter-nu` installed via
`treesit-install-language-grammar`.

**LSP:** `nu --lsp` (built-in since Nu 0.85); no external binary. `lsp-mode` has no
built-in Nushell client — must use `lsp-register-client` with
`lsp-stdio-connection '("nu" "--lsp")`.

**Template:** `:lang zig` (`modules/lang/zig/config.el`) — simplest clean example of a
`+LANG-common-config` helper + `modulep! +lsp` flag pattern + tree-sitter conditional.

**Contributing bar:**
- Target `master`; package pins required; module documentation required
- Do-not-PR list moved to `discourse.doomemacs.org/do-not-pr` (login required to read)
- Contributing guide's "Contributing a new module" section is empty — ask on Doom
  Discord before opening the PR

Full research captured in `nushell-doom-module.md`.

---

### 2026-05-28 20:14 — Go module research; go-doom-module.md created

Doom's `(go +lsp)` module is far more comprehensive than anticipated. It wires gopls
auto-start, format-on-save via `:editor format`, a REPL (`gorepl-mode`), struct tag
management (`go-tag`), test generation (`go-gen-test`), and an extensive local-leader
binding set covering run/build/clean, tests, benchmarks, generate, and godoc. Full
binding table in `go-doom-module.md`.

Consequence for systems-ide: `go-keybindings.el` will be sparse (possibly empty beyond
a reference comment) since the module covers the main use cases. `config.el` addition
is a single `(load! "go-keybindings")` line.

The one open decision is `golangci-lint` — deferred. gopls staticcheck covers the
common ground; golangci-lint can be added in a later hardening pass if needed.

Dockerfile work (go-build stage, COPY, ENV, gopls install) is next and is AI's to
write.

---

### 2026-05-30 — go-keybindings.el completed; binding design finalized

`go-keybindings.el` was fleshed out from a bare reference comment to a complete
binding file. The design session covered all of `(go +lsp)`'s capability clusters and
produced a coherent custom binding layer on top of the module defaults.

#### Binding decisions

**`SPC m I` — add import shortcut.** The module's `go-import-add` binding lives at
`SPC m r i a` — a four-key sequence. `SPC m I` (capital I) provides a direct shortcut,
pairing with `SPC m i` (goto-imports): lowercase navigates the import block, uppercase
adds to it. The `SPC m r` prefix is reclaimed for REPL (see below), making the shortcut
a necessity rather than just convenience.

**`SPC m l` / `SPC m L` — lint.** `l` lints the current package (`golangci-lint run .`);
`L` lints all packages (`golangci-lint run ./...`). Follows the lowercase/uppercase
smaller-to-larger-scope pattern established with `i`/`I`. Both run via `compile`, sending
output to a `*compilation*` buffer. `golangci-lint` is not yet in the image (deferred per
`go-doom-module.md`); bindings are wired now so the binary drop-in makes them live.

**`SPC m p` — profile/benchmark prefix.** Carries over from the prior scaffolding session.
Shadows the module's `SPC m t b s/a` to put benchmarks under a dedicated prefix.

**`SPC m r` — REPL prefix.** Shadows the module's `SPC m r` import subtree entirely
(covered by `SPC m I`). Sub-bindings follow a consistent lowercase=smaller /
uppercase=larger scope ladder:

| Key | Function | Scope |
|---|---|---|
| `SPC m r e` | `gorepl-eval-line` | line |
| `SPC m r n` | `gorepl-eval-line-goto-next-line` | line + advance |
| `SPC m r E` | `gorepl-eval-region` | region |
| `SPC m r r` | `gorepl-run` | bare REPL |
| `SPC m r R` | `gorepl-run-load-current-file` | REPL + current file |

`gorepl-run-load-current-file` seeds the REPL with the current file's declarations,
making types and functions available for interactive exploration without re-entering
them. Gore wraps input in a temporary `main` package and compiles on the fly; `main()`
side effects don't auto-run — individual functions are called explicitly.

`gorepl-eval-line-goto-next-line` (bound to `n`) was discovered in the gorepl-mode
source during the design session; it evaluates the current line then advances the cursor,
useful for stepping through expressions sequentially.

**Note:** All REPL bindings require the `gore` binary (`github.com/x-motemen/gore`),
which is not yet in the Dockerfile. gopls and dlv are installed; gore is not.

#### Comment trimming

The `go-keybindings.el` reference comment originally included a "LOCAL-LEADER — custom"
section mirroring the `map!` calls. This was removed: the code is self-documenting and
the duplicate comment would drift from the code as bindings change. The comment now
covers only the built-in module bindings — including shadowed ones as signposts pointing
to their replacements.

---

### 2026-05-30 — Font investigation; all-the-icons fonts added to Dockerfile

#### Background

A broken glyph appeared in the modeline to the left of the LSP rocket/Go-version display.
Clicking it revealed it was the LSP code action indicator — clicking it opened the
"Select Code Action" prompt normally. The icon itself was broken, not the feature.

#### Root cause

`lsp-modeline` renders the code action icon via `lsp-icons-all-the-icons-icon`, which
calls `all-the-icons-octicon "light-bulb"` when `all-the-icons-octicon` is `fboundp`.
`all-the-icons` is present in the image as a transitive dependency, so the function IS
bound. lsp-mode therefore bypasses its own `💡` fallback and tries to render using the
`all-the-icons` octicons font — which was never installed. The result is a broken glyph
rather than a fallback character.

#### What was tried first

`nerd-icons-install-fonts` (which installs `NFM.ttf`) was added to the Dockerfile. This
did not fix the icon because lsp-mode's code action indicator uses `all-the-icons`, not
`nerd-icons`. `NFM.ttf` is the correct font for `nerd-icons` glyphs but has no bearing
on `all-the-icons` rendering.

The nerd-icons equivalent glyph was identified as `nf-cod-lightbulb` (codicons). A
config.el override using `lsp-modeline-code-action-icons-enable nil` combined with
`lsp-modeline-code-action-fallback-icon` was considered but not pursued — lsp-mode
re-propertizes the fallback string in a way that could strip nerd-icons font metadata.

#### Resolution

All six `all-the-icons` font files installed to `~/.local/share/fonts/` in the fonts
`RUN` step, each verified with SHA256:

| Font file | SHA256 (first 16 chars) |
|---|---|
| `all-the-icons.ttf` | `f0a1ecf206d49af4` |
| `file-icons.ttf` | `f37a5c02cf028580` |
| `fontawesome.ttf` | `ae19e2e4c04f2b04` |
| `material-design-icons.ttf` | `b7f4a3ab562048f2` |
| `octicons.ttf` | `027e1b2278bd2ea3` |
| `weathericons.ttf` | `176bda6661f213dd` |

Downloaded from `https://raw.githubusercontent.com/domtronn/all-the-icons.el/master/fonts/`.
`all-the-icons` is not pinned in Doom's `packages.el` at the locked commit — it arrives
as a transitive dependency at `master`. The font files are stable binary assets; the
SHA256s pin them at the versions current as of this build.

#### Status

All-the-icons fonts added to Dockerfile at this point. Icon still not fixed — see
follow-up entry below.

#### Corrected: invalid `--fonts` flag

The Dockerfile had `doom install -! --aot --fonts`. The `--fonts` flag does not exist
at the pinned Doom commit (`4e0dbb9`) — confirmed by reading `lisp/cli/install.el`.
The flag was removed. Font installation is handled entirely by the explicit download
steps in the fonts `RUN` block.

---

### 2026-05-30 — Code action icon: diagnosis corrected; fixed via config.el

After rebuilding with the all-the-icons fonts, the icon was still broken. In-editor
diagnosis via `M-:` produced the following:

```
(fboundp 'all-the-icons-octicon)  →  nil
(all-the-icons-octicon "light-bulb")  →  void-function error
(lsp-icons-all-the-icons-icon 'octicon "light-bulb" 'default "💡"
  'modeline-code-action :v-adjust -0.0575)  →  #("<broken icon>" 0 1 (face default))
```

#### Revised root cause

`all-the-icons` is not installed at all — Doom has fully migrated to `nerd-icons` at
the pinned commit and `all-the-icons` is not a transitive dependency of anything in
this configuration. The prior assumption that `all-the-icons-octicon` was `fboundp`
was wrong; it was never tested at the time it was made.

Because `all-the-icons-octicon` is void, `lsp-icons-all-the-icons-icon` always falls
through to `(propertize lsp-modeline-code-action-fallback-icon 'face face)`. The
fallback is the `💡` emoji (U+1F4A1), which renders as `<broken icon>` in the modeline
— the terminal output `#("<broken icon>" 0 1 ...)` is the emoji failing to render in
that context, not a literal string.

The all-the-icons font files added in the previous session are therefore dead weight —
the package that would use them is absent. They were removed from the Dockerfile and
their six ARGs were removed from the ARG block.

#### Resolution

`lsp-modeline-code-action-fallback-icon` set to `(nerd-icons-codicon "nf-cod-lightbulb")`
in `config.el` via `(after! lsp-mode ...)`. The codicon lightbulb is U+EA61, which sits
in the Unicode private use area. `nerd-icons` registers a fontset mapping for PUA
codepoints pointing to `NFM.ttf` at startup. When lsp-mode re-propertizes the fallback
string with `face default`, the character U+EA61 still resolves to `NFM.ttf` via the
fontset mapping — the face override does not strip fontset entries. The icon renders
correctly without any `all-the-icons` involvement.

**Confirmed working** after rebuild.

---

### 2026-05-30 — Go tooling: gore, golangci-lint, gomodifytags added to Dockerfile

Three Go binaries were missing from the image, each corresponding to bindings already wired in `go-keybindings.el`:

- **`gore` v0.6.0** — the binary `gorepl-mode` shells out to. Without it, `SPC m r r/R/e/n/E`
  fails with `"Searching for program: No such file or directory, gore"`. Installed via
  `go install github.com/x-motemen/gore/cmd/gore@v0.6.0`. gore uses the already-installed
  `gopls` for code completion; no additional dependencies needed.

- **`golangci-lint` v2.11.4** — backing `SPC m l/L`. Must be installed via the official
  install script rather than `go install` (the project explicitly warns that `go install`
  produces a binary with wrong build flags that breaks plugin support). `v2.12.2` was
  attempted first but its install script checksum verification failed — the downloaded
  tarball SHA256 did not match the release's `checksums.txt`. Fell back to `v2.11.4`.
  Note: golangci-lint v2 changed its config file format; existing `.golangci.yml` files
  written for v1 are not compatible.

- **`gomodifytags` v1.16.0** — backing `SPC m a` (add struct tag) and `SPC m d` (remove
  struct tag). Plain `go install github.com/fatih/gomodifytags@v1.16.0`.

All three were consolidated into the existing Go tools `RUN` step alongside `gopls` and
`dlv`, with the golangci-lint install script pipe as the first command (its exit status
propagates through `&&` to gate the subsequent `go install` calls).

**`SPC m l` / `SPC m L` and `SPC m a` / `SPC m d` confirmed working.**

---

### 2026-05-30 — gorepl-run autoload fix

`SPC m r r` (`gorepl-run`) failed cold with `"Symbol's function definition is void:
gorepl-run"`. `SPC m r R` (`gorepl-run-load-current-file`) worked, and after running it
`SPC m r r` worked too — confirming `gorepl-mode` is installed but `gorepl-run` has no
`;;;###autoload` cookie. `gorepl-run-load-current-file` does have one, so calling it loads
the whole package and defines `gorepl-run` as a side effect.

Fix: `(require 'gorepl-mode)` added as the first form inside the `cmd!` for the `"r"`
binding in `go-keybindings.el`. `require` is a no-op once the package is loaded, so
subsequent invocations pay no cost. The comment block above the REPL bindings was updated
to document both issues: the missing `(interactive)` on gorepl stubs generally, and the
missing autoload cookie on `gorepl-run` specifically.

**`SPC m r r` confirmed working cold. NFM.ttf baked into the image correctly — `nerd-icons-install-fonts` no longer needed on first boot.**

---

### 2026-05-30 — flight-tests directory scaffolded; run.sh gains `-f` flag

`flight-tests/go/` added under `systems-ide/` as a per-language flight-test home.
Mounted at runtime (not baked into the image) so the files stay editable on the host
without a rebuild.

`run.sh` updated with a `-f lang1,lang2,...` flag that mounts each named language
subdirectory into `~/flight-tests/<lang>` inside the container. Missing directories
produce a stderr warning and are skipped rather than aborting. Example:

```
./run.sh -f go,nu
```

`flight-tests/go/go.mod` declares `module docker-emacs/systems-ide/flight-tests/go`,
`go 1.25`, `toolchain go1.25.7`. Declares a version the container doesn't install
directly (container ships 1.26.x) so gopls version-enforcement and GOTOOLCHAIN=auto
behaviour are both exercised as part of the flight test.

---

### Next build queue

**1. Install `godef`**

`SPC m h .` (godoc at point) and the default `K` binding both call `godef`, which is not
in the image. Add to the Go tools `RUN` step:

```dockerfile
go install github.com/rogpeppe/godef@latest
```

**2. Install `gotests`**

`SPC m t g/G/e` (generate test stubs) failed with `"Symbol's value as variable is void:
shell-mode-hook"` — `gotests` binary is missing. Add to the Go tools `RUN` step:

```dockerfile
go install github.com/cweill/gotests/gotests@latest
```

**3. Override `K` to LSP hover**

The go-keybindings.el comment already documents `K` as LSP hover, but Doom's go module
binds it to `godoc-at-point` (godef-backed) instead. Add to `go-keybindings.el`:

```elisp
:desc "Hover docs" "K" #'lsp-describe-thing-at-point
```

(under `:map go-mode-map :localleader` — Josiah writes the `map!` call)

**4. `flycheck-golangci-lint` — inline lint diagnostics**

golangci-lint currently only runs on demand (`SPC m l/L`). To surface errors inline on
save, add the flycheck integration package.

`packages.el`:
```elisp
(package! flycheck-golangci-lint)
```

`config.el` (Josiah writes):
```elisp
(use-package! flycheck-golangci-lint
  :hook (go-mode . flycheck-golangci-lint-setup))
```

**5. Fix `gorepl-eval-region` double-indentation** — tracked in [#21](https://github.com/josiah14-automation-engineering/docker-emacs/issues/21)

---

### 2026-06-05 — godef incompatible with Go 1.26+; dropped in favour of LSP hover

Items 1–4 from the queue above were implemented and the image rebuilt. During flight
testing, `SPC m h .` (godoc at point) produced `"godoc: doc: no such package: nil"`.
Manual invocation confirmed the cause:

```
godef -f flight-test.go -o <offset>
# → panic: runtime error: invalid memory address or nil pointer dereference
#   golang.org/x/tools@v0.0.0-20200226224502-204d844ad48d
```

`godef@latest` pulls `golang.org/x/tools` frozen at February 2020, which predates Go
1.21's reorganisation of `internal/goarch`. The nil-pointer panic fires at type-check
time and cannot be worked around without a new release from upstream. The project has
had no release since 2020 and is effectively abandoned.

**Fix:** removed `godef` from the Go tools `RUN` step (Dockerfile comment documents the
reason). `SPC m h .` remapped to `lsp-describe-thing-at-point` in `go-keybindings.el`
— gopls hover is strictly superior. See DECISIONLOG for full rationale.

**Josiah caught:** the `"Symbol's value as variable is void: shell-mode-hook"` error
that surfaced when trying to run shell commands from within the editor (`!`) confirmed
the known `shell-mode-hook` bug is still present; diagnosed independently during this
session. Josiah also independently reasoned that `SPC m t g/G/e` failures were the same
bug resurfacing (test commands spawn a shell subprocess), not a missing `gotests` binary
— to be confirmed after rebuild.

**Josiah adjusted:** `SPC m h .` prefix key changed from uppercase `H` to lowercase `h`
(`SPC m k` was unbound; `h` is easier to type). Too granular for DECISIONLOG.

**`SPC m e` — playground send remapped to kill-ring yank:** no browser in the container,
so `+go/playground` can't open play.golang.org. Implemented `+go/playground-yank` in
`go-keybindings.el`: `let`-binds `browse-url-browser-function` to a lambda that calls
`kill-new` and `message` instead of opening a browser, then calls `+go/playground` via
`call-interactively` so region detection works correctly. Josiah walked through the
implementation unprompted with near-zero elisp background — correctly identified
`(interactive)`, `let`, `browse-url-browser-function`, `kill-new`, and `message`;
needed only minor corrections on `&rest _` and `call-interactively`. Josiah authored
the final code; two minor typos caught in review (`atteempting`, `Payground`) and
corrected before build. **`SPC m e` confirmed working** — URL copied to kill ring and
verified live at play.golang.org.

### 2026-06-05 — fix `shell-mode-hook` void variable bug

**Root cause:** `shell.el` used `(provide 'shell)`, shadowing Emacs's built-in
`shell.el`. Any `(require 'shell)` call triggered by test commands, `:!`, or anything
spawning a shell subprocess saw the feature as already provided, skipped the built-in,
and left `shell-mode-hook` undefined. Fixed by renaming to `(provide 'systems-ide-shell)`.
`config.el` uses `(load! "shell")` which loads by filename, not feature name, so no
other changes were needed.

**`SPC m t g/G/e` confirmed working** — all three gotests bindings verified after fix.
`gotests` generates stubs correctly; "No tests generated" is expected when all exported
functions already have coverage.

### 2026-06-05 — performance review: multi-language IDE viability

Reviewed whether supporting the full language stack in a single IDE would degrade
editor performance. Conclusion: no meaningful Emacs-internal concern.

- **Startup / responsiveness** — unaffected; Doom's lazy loading and AOT compilation
  mean language support only activates when a relevant file is opened. Installing more
  modules doesn't increase cold-start time meaningfully.
- **Simultaneous LSP servers** — each active language runs its own process. gopls and
  rust-analyzer are the most memory-hungry; in practice multiple languages are rarely
  active simultaneously.
- **rust-analyzer** — initial workspace indexing can cause a few seconds of sluggishness
  on large projects; one-time cost per workspace.
- **nix-direnv** — first `use flake` evaluation per project hits the network and nix
  evaluator (seconds); subsequent activations are instant via nix-direnv's cache.
- **company-nixos-options** — already disabled for idle completion by Doom's nix module
  (noted in source as "dreadfully slow"); manual invocation only.

**Josiah's call:** splitting Rust and Nix into separate IDEs would not solve these
issues — the overhead is process-level (LSP server memory, nix evaluation), not elisp
stepping on itself. A single systems-ide keeps things simple without a real performance
tradeoff.

---

### 2026-06-06 — Step 3 (Nix): nix-source image built and smoketested

#### Architecture: nix-source image

The original Step 3 spec called for inlining the Nix install directly in the
systems-ide Dockerfile: download installer, run `--no-daemon`, install nil and
nix-direnv into the profile. The implementation was started when Josiah paused it:

> "let's think about this actually, it may be beneficial for nix to be a reusable
> stage that can be derived from because I expect actually that most of the IDEs are
> going to need to have nix integrated since it's a general purpose tool for declaring
> a dev environment with the system dependencies installed."

Three options were laid out:

**Option A — published base image:** a new intermediate image that IDEs extend via
`FROM`. Every IDE inherits Nix through the image chain. One place to maintain; clean
cache behaviour (bumping the base triggers IDE rebuilds, but only from the base layer
onward). Downside: adds a mandatory publish step to the build chain; changes the
fundamental FROM relationship for all future IDEs.

**Option B — multi-stage COPY source:** a dedicated nix image used purely as a
`COPY --from=nix-source` target, exactly like the existing emacs-build dev image.
IDEs still start `FROM ubuntu:24.04` and compose in the Nix artifacts. No inheritance
chain; each IDE's final image is built from scratch with Nix content copied in.

**Option C — inline in each Dockerfile:** duplicate the install block per IDE. Version
bumps touch every Dockerfile; drift is possible over time.

Josiah confirmed Nix belongs in every IDE, which ruled out Option C. The initial
recommendation was Option A (base image) for its DRY properties. Josiah chose
**Option B**, explicitly modelling it on the existing dev/ pattern:

> "yah, let's put this in the 30.2 ubuntu 24.04 x86_64 dir under a new nix/ dir and
> derive from it similarly to how we currently derive from the base emacs image in
> dev/ under there to get the emacs binary."

The distinction matters: Option A is inheritance (the IDE IS a nix image); Option B
is composition (the IDE HAS nix content copied into it). Composition preserves the
existing pattern where every final image starts from a clean `ubuntu:24.04` and only
the specific binary artifacts are assembled in — apt packages, Emacs binary, Go
toolchain, and now the Nix store and profile. The nix image is a build-time
dependency, not a runtime parent.

The new image lives at `30.2/ubuntu/24.04/x86_64/nix/` and produces
`josiah14/nix:2.33.3-ubuntu-24.04`. IDEs add `FROM josiah14/nix:2.33.3-ubuntu-24.04
AS nix-source` and COPY `/nix` and the relevant home dotfiles rather than running the
installer themselves. One place to bump `NIX_VERSION`; no version drift across IDEs.

#### Experimental features

All 19 capability experimental features enabled in `~/.config/nix/nix.conf`. Three
flags excluded: `no-url-literals` and `read-only-local-store` (opt-in restrictions, not
capabilities), `daemon-trust-override` (security override). `auto-allocate-uids` and
`cgroups` are inert in `--no-daemon` mode but harmless to enable.

`printf '%s\n'` with per-line backslash-continuation strings was the first approach;
it wrote the literal `\` characters into `nix.conf`, producing a parse error on the
second feature name. Fixed to a single `printf` with the full space-separated list on
one line — nix.conf has no backslash continuation syntax.

#### Smoketest results (all passing)

- `nix 2.33.3`, `nil 2025-06-13`, `direnv 2.37.1` all on PATH from `~/.nix-profile/bin`
- `nix.conf` contains all 19 features as a single-line value
- `nix eval --expr '[1 2 3 4] |> builtins.length'` → `4` (pipe-operators active)
- `nix flake metadata nixpkgs` resolves, fetches metadata
- `nix develop` on a test flake with `jq` — shell activates, `SMOKETEST_OK=yes`
- `direnv allow` + `eval "$(direnv export bash)"` — env exported, `which jq` → nix store path

Two SMOKETEST.md corrections made post-run: grep pattern for symlinks (removed trailing
`$` anchor); `readlink ~/.nix-profile` expected path updated to
`~/.local/state/nix/profiles/profile` (Nix 2.33 relocated profiles from
`/nix/var/nix/profiles/per-user/`).

#### Josiah catches

- **Inline install rejected in favour of nix-source image** — redirected before any
  Dockerfile work was committed.
- **Three sloppy revert rejections** — an attempt to "revert" the inline install as a
  pure deletion (without adding the COPY replacement) would have left the final image
  without a `direnv` binary, without a `/nix` directory, and without a `~/.nix-profile`.
  Josiah caught all three separately; each was a correct rejection. Fixed by deferring
  the systems-ide rewire to a dedicated task rather than treating it as a two-step
  delete-then-add.

#### Remaining for systems-ide (next session)

- **Task #3** — Dockerfile rewire: add `FROM nix-source`, COPY layers, ENV PATH, remove
  inline block and `direnv` from apt
- **Task #4** — `(nix +lsp)` in `init.el`; `(load! "nix-keybindings")` in `config.el`
- **Task #6** — BATS smoketest for the nix image

---

**`SPC m h .` still calling godef** — `map!` in `go-keybindings.el` runs at startup, but
Doom's go module wires `h . → godoc-at-point` inside `+go-common-config`, which is called
from `use-package! go-mode :config`. That `:config` block runs lazily on first `.go` file
open — after our `map!` — so the module's binding overwrites ours. Fix: move the `h .`
override into `go-config.el` inside `(after! go-mode ...)`. Since `config.el` registers
that hook after the module, it runs last and wins. The `(:prefix ("h" . "help") ...)`
block in `go-keybindings.el` is a no-op and should be removed.

---

### 2026-06-06 — Step 3 (Nix): systems-ide Dockerfile rewired; nix module activated

#### Task #3: Dockerfile rewire (single atomic pass)

The prior session's three sloppy revert rejections established the principle: rewire as
a single atomic edit, not a delete-then-add sequence. Implemented in one pass:

- `FROM josiah14/nix:2.33.3-ubuntu-24.04 AS nix-source` added as the third build stage
  (after `emacs-build` and `go-build`).
- `direnv \` removed from the apt list — `direnv` binary arrives via `~/.nix-profile/bin`
  from the COPY block.
- `RUN mkdir -m 0755 /nix && chown...` replaced with four `COPY --from=nix-source` lines:
  `/nix`, `~/.local/state/nix`, `~/.config/nix`, `~/.config/direnv`. All with
  `--chown=${USERNAME}:${USERNAME}`.
- `RUN ln -sf "/home/${USERNAME}/.local/state/nix/profiles/profile" "/home/${USERNAME}/.nix-profile"`
  added after the USER switch. Explicit symlink creation rather than COPY of the symlink
  itself — Docker COPY's symlink-following behaviour in `--from` context is ambiguous;
  explicit `ln -sf` is unambiguous.
- Inline `NIX_VERSION`, `NIX_SHA256`, and `RUN curl` Nix installer block removed.
  `ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"` kept in place.

Both images must be built with the same `USERNAME` (both `build.sh` files pass
`--build-arg USERNAME="${USER}"`), so COPY source paths `/home/${USERNAME}/...` align
with the build ARG in the final stage.

#### Task #4: Doom nix module activated

- `(nix +lsp)` added to `:lang` block in `init.el` (alphabetically between `markdown` and `org`).
- `(load! "nix-keybindings")` added at the end of the load block in `config.el`.

#### nix-keybindings.el: f/p swap and reference comment

The Doom nix module ships `f → nix-update-fetch` and `p → nix-format-buffer` — the
inverse of the cross-IDE convention used elsewhere in this image. The file overrides
them: `f → nix-format-buffer`, `p → nix-update-fetch`.

The reference comment documents the unchanged module defaults (`r`, `s`, `b`, `u`, `o`)
and the LSP slots added by nil (`g`, `h`, `a`, `r`). The `r` collision between
`nix-repl-show` and LSP rename is noted: whichever `map!` runs last wins; in practice
LSP rename takes `r` once lsp-mode is active.

Two comment revisions during authoring: Josiah directed that `f` and `p` be removed from
the defaults table (they're declared below and the file is the source of truth — no need
to document what the defaults were). A brief note near the `map!` call marks them
explicitly as overridden defaults, not unbound or unimplemented bindings.

#### Remaining

- **Task #5** (build) — systems-ide image has not been rebuilt with the rewired Nix layers yet.
- **Task #6** — BATS smoketest for the nix image.
- **Flake bindings** — `SPC m l` as a flake prefix (`nix flake check / update / develop`)
  under discussion; Josiah's inclination is `l` to avoid the shift key.

---

### 2026-06-15 — Shared host Nix store: version bump, bind mounts, smoketest

#### nix-source bumped to 2.34.7 (host version reconciliation)

`systems-ide/Dockerfile`'s `nix-source` stage now reads `FROM josiah14/nix:2.34.7-ubuntu-24.04`, matching the host's Nix upgrade (2.33.3 → 2.34.7) and `nix/Dockerfile`'s new single-source-of-truth `ARG NIX_VERSION`. See mercury-ide's BUILDLOG for the full NIX_VERSION-duplication discussion and Josiah's resulting design: `nix/Dockerfile` pins the version, `nix/build.sh`/`nix/run.sh` derive it via `grep`, and each IDE's `nix-source` `FROM` tag stays an explicit, independently-pinnable declaration (an IDE that needs to stay behind can pin an older tag and keep its own `/nix` store inside the container).

#### run.sh: /nix, ~/.local/state/nix, ~/.config/nix bind mounts

Added the same three bind mounts as mercury-ide's `host/logic-languages-ide`: `-v /nix:/nix`, `-v "${HOME}/.local/state/nix:/home/${USER}/.local/state/nix"`, `-v "${HOME}/.config/nix:/home/${USER}/.config/nix"`, inserted after the `Development/personal` mount and before `-w`. The container now shares the host's `/nix/store`, `nix.conf`, and `~/.nix-profile`-backing profile — the `nix-source` COPY block is a first-boot seed rather than the live source.

#### nix-smoketest.bats: new suite (7 tests)

Added `systems-ide/nix-smoketest.bats`, structurally identical to mercury-ide's: version match, store info, `pipe-operators` in `nix.conf` and in `nix eval`, `nix profile list` parity (`direnv`/`nil`/`bats`), `nil`/`direnv` on PATH, host-built `hello` visible in `/nix/store`.

systems-ide's first run was 6/7 — `nix-env -q` failed because the host's profile generation (created via `nix profile install`) is in a manifest format `nix-env` can't read (see mercury-ide's BUILDLOG for the diagnosis). After swapping that test to `nix profile list` in both IDEs' suites, systems-ide re-ran 7/7. Josiah then committed the container, separately noting that a committed image starts roughly 0.5s faster than a fresh `--rm` run on a subsequent launch — plausibly overlay2 layer-initialization overhead on first start.

---

### 2026-06-16

#### run.sh: conditional host Nix detection, RO mount split, MOUNT_HOST_NIX escape hatch

Same hardening as mercury-ide's `host/logic-languages-ide` (see mercury-ide BUILDLOG, 2026-06-16). `run.sh` previously mounted `/nix`, `~/.local/state/nix`, and `~/.config/nix` unconditionally and read-write.

- **Conditional detection:** mounts guarded by `[[ -d /nix ]]`; container falls back to the baked-in `nix-source` store when no host `/nix` exists.
- **Read-only split:** `/nix:ro`, `/nix/var/nix` rw (lock/temproots), `/nix/var/nix/profiles:ro` (re-pinned), `~/.config/nix:ro`, `~/.local/state/nix:ro`.
- **`MOUNT_HOST_NIX=0` escape hatch:** full guard is `[[ -d /nix ]] && [[ "${MOUNT_HOST_NIX:-1}" == "1" ]]`; opt out without touching the host's `/nix` directory when the store exists but is corrupt or mid-upgrade.

Josiah verified the pattern in mercury-ide before applying it here.

---

### 2026-07-14

#### Bats language support (ported from the aarch64/26.04 port)

Added `.bats` as a fourth IDE-supported language (Shell/Go/Nix/Bats), matching
the pattern already used for those three: `packages.el` gets `(package!
bats-mode)` (dougm/bats-mode — confirmed present in MELPA's live
`archive-contents`, source read from GitHub to confirm the real interface),
`config.el` gets `(load! "bats-keybindings")`, new `bats-keybindings.el`
(no `after!` wrapper — no Doom `:lang` module exists for bats to race
against, same reasoning as `sh-keybindings.el`), and the Dockerfile installs
`bats` via apt (confirmed against `packages.ubuntu.com/noble/bats`,
1.10.0-1, arch: all) and `COPY`s the new keybindings file in. `bats-mode`
derives from `sh-mode`, sets `sh-shell` to `bash`, and wires flycheck's
shellcheck checker itself — no `init.el` `:lang` entry needed, same shape as
`nushell-mode`.

This is distinct from **Task #6** above (BATS smoketest for the nix image,
`nixpkgs#bats` alongside nil/direnv) — that's about installing `bats` as a
*test-running tool* via the shared nix profile for this project's own
`smoketest.bats` harness; today's change is about editing/running `.bats`
files as an IDE language via apt, independent of the nix bridge. Task #6
(and porting the aarch64 port's `smoketest.bats`/`nix-smoketest.bats`/`-t`
flag additions here) is still open — Josiah is picking that up separately
on the system76 machine.

#### Bug found on the aarch64 port after rebuild: `.bats` files stayed in `sh-mode`

Surfaced there as an `lsp-mode` "no language servers... registered with
`sh-mode'" warning (modeline `Sh [bats]`, `major-mode` reporting `sh-mode`
directly). Traced to `bats-mode`'s own `auto-mode-alist` autoload
registration not taking effect — `sh-mode`'s built-in shebang sniffing
(`sh-set-shell`) was winning the race and binding `sh-shell` to the literal
token `bats` before `bats-mode` ever ran. Confirmed via `lsp-bash.el`/
`lsp-mode.el` source that this was never an LSP-configuration issue:
`bash-ls`'s `:activation-fn` only checks the `sh-shell` variable (which a
genuine `bats-mode` buffer sets to `'bash` itself), not `major-mode`.

Fixed defensively in `bats-keybindings.el` (both ports) by adding an
explicit `(add-to-list 'auto-mode-alist '("\\.bats\\'" . bats-mode))`
ourselves rather than relying solely on the package's own autoload cookie.
Root cause of why the package's own registration didn't fire was not fully
isolated; full detail in the aarch64 port's `BUILDLOG.md` (2026-07-14
entry). Applied here too since `bats-keybindings.el` is otherwise
byte-identical between the two ports.

**Update**: the `add-to-list` fix above turned out to be incomplete —
actual root cause was `sh-script.el` registering `.bats → sh-mode` as a
plain top-level form (not an autoload cookie), which only fires once
`sh-script.el` is actually `require`d and can re-win the race afterward. A
reactive `with-eval-after-load` correction still lost on a genuinely fresh
container, since opening the first `.bats` file is itself what triggers
`sh-script.el`'s load. Final fix forces `(require 'sh-script)` eagerly in
`bats-keybindings.el`, immediately followed by the `setf`/`alist-get`
correction, closing the race before any `.bats` buffer is ever opened.
Full diagnostic trail (the `M-:` checks that isolated the two competing
alist entries, and the cold-start retest that exposed the gap in the first
fix) is in the aarch64 port's `BUILDLOG.md`, 2026-07-14. Applied
identically to both ports' `bats-keybindings.el`, which stays
byte-identical between them.

**Update**: even with `.bats` correctly landing in `bats-mode`, `bash-ls`
still never attached — `(lsp!)` silently no-oped. Two independent bugs in
the `with-eval-after-load 'lsp-mode` registration block: (1) `cl-pushnew`
on `lsp--client-major-modes` byte-compiles into a call to a literal
`(setf lsp--client-major-modes)` function that's never defined, since that
accessor's `setf` support is a runtime-registered `gv-expander`, not
available at Doom's compile time — fixed via `cl-struct-slot-value`
instead, whose `setf`-expander lives in `cl-lib` and is always available;
(2) `bash-ls` itself is registered by the separate `clients/lsp-bash.el`,
which only auto-loads once some buffer's major-mode already matches one of
its modes — never true for `bats-mode` on its own — so the `gethash`
lookup came back `nil`. Fixed by forcing `(require 'lsp-bash)` inside the
hook before the lookup. A long red herring (suspected stale/corrupted
native-compiled `lsp-mode`) preceded both finds and is documented in full,
along with the exact fixes and a `DOOMDIR`-vs-live-mount testing gotcha
discovered along the way, in the aarch64 port's `BUILDLOG.md`, 2026-07-14
("LSP integration: bash-ls never attached to bats-mode buffers"). Applied
identically here since `bats-keybindings.el` stays byte-identical between
the two ports.

**Update**: even after both fixes, a genuine cold start (fresh IDE, open
`smoketest.bats` first thing, no manual `(lsp!)`) still didn't attach —
narrowed to a missing invocation, not a registration problem, since manual
`(lsp!)` still worked. Doom's `:lang sh +lsp` module hooks `lsp!` onto
`sh-mode-local-vars-hook`, which only fires for literal `sh-mode` buffers,
not `bats-mode` (despite deriving from it) — with no Doom `:lang` module
for bats, nothing called `lsp!` automatically. Fixed with
`(add-hook 'bats-mode-local-vars-hook #'lsp! 'append)`, mirroring Doom's
own hook. Also swapped `with-eval-after-load 'lsp-mode` to Doom's `after!`
(matching this project's other keybinding files and the style guide) and
reworded the `rm -rf .../straight/build-*` Dockerfile comment, which had
stated the ruled-out stale-bytecode theory as fact. Full detail in the
aarch64 port's `BUILDLOG.md`, 2026-07-14 ("LSP integration, part 2:
cold-start still didn't attach"). Confirmed working on a genuine cold
start on aarch64; x86_64 rebuild and retest pending.

---

### 2026-07-16 — Nushell actually wired up, then switched to nushell-ts-mode

`nushell-mode`/`nu-keybindings.el` had existed since the 2026-05-28
research entry above but were dead: never `load!`-ed, no real bindings,
`nu` itself not installed. Wired up properly this session: `nu` binary
installed via a verified-current release tarball (`gh release view`, not
guessed), `nu-config.el` added (`after! lsp-mode (require 'lsp-nushell)`
+ `(add-hook 'nushell-mode-local-vars-hook #'lsp! 'append)`, same fix
shapes bats needed), `nu-keybindings.el` given real bindings (execute
region/buffer via `nu -c`/`nu FILE`). `lsp-mode`'s own `lsp-nushell.el`
client and default `lsp-language-id-configuration` already covered
`nushell-mode` — no manual client-registration hack like bats needed.

Same session, reworked file conventions across *all* language files, not
just nu's: split `bats-keybindings.el`'s plumbing into a new `bats-
config.el` (matching `go-config.el`/`go-keybindings.el`'s existing split),
renamed `shell.el` → `shell-config.el` (and its `provide` from
`'systems-ide-shell` to `'shell-config`, still avoiding the original
collision with Emacs's built-in `shell.el` documented earlier in this
log, just less ad-hoc about it), added proper `;;; file.el --- Summary`
headers / `Commentary:` / `Code:` / `ends here` footers to every language
file (previously only `go-keybindings.el` had the full convention), and
added a `LOCAL-LEADER` cheat-sheet to each file's own `Commentary:`
section listing its actual custom bindings (previously only the generic
Doom-default reference bindings were documented, the least interesting
part). x86_64's `smoketest.bats` didn't exist at all before this (only
`nix-smoketest.bats`) — confirmed all pinned tool versions match aarch64's
Dockerfile first, then ported the *whole* suite over, not just nu's cases.

**Then**: plain `nushell-mode` turned out to have no working indentation
(a `nushell-enable-auto-indent` flag defaulting off, referencing a
trigger-keywords variable never actually defined in the package). Switched
to `nushell-ts-mode` (tree-sitter based, genuinely implements indent
rules, completion-at-point, and imenu) — a strict upgrade, with one new
consideration: it depends on the `tree-sitter-nu` grammar being compiled
from C source at build time, a real new moving part plain `nushell-mode`
never needed. First rebuild's smoketest still failed to activate
`nushell-ts-mode`; rather than guess again, a throwaway debug container
(`docker run -d ... sleep 3600`) found two things a live daemon session
could show that a plan couldn't: no `cc` on `PATH` at all (`libgccjit-dev`
only provides the native-comp *library*, not a compiler binary — added
plain `gcc`), and Doom redirects its tree-sitter grammar search path to
`~/.config/emacs/.local/cache/tree-sitter` rather than vanilla Emacs's
default, confirmed by testing against a real `emacs --daemon` (`--batch`
alone doesn't replicate Doom's actual interactive startup, same gap
already noted for `doom-font`/module config). Full account, including the
hung-daemon detour from an unanswerable "import project?" prompt, is in
the aarch64 port's `BUILDLOG.md`, same date ("Nushell follow-up: switched
to nushell-ts-mode for working indentation"). Both fixes applied to both
ports' Dockerfiles; confirmed working (all 25 smoketests, including
`nushell-ts-mode` activation) on aarch64. x86_64 rebuild/retest pending.

---

### 2026-07-17 — C/C++/CMake added as a sixth language; package managers wired in

`c-keybindings.el` and `cmake-keybindings.el` existed only as the empty
placeholder files scaffolded at project start (see the 2026-05-06 entries
above) — never `load!`-ed, no toolchain installed. Wired both up per the
project's original "Language stack decisions" spec above (`C/C++`: full IDE
support, `clangd`, both `gcc`/`g++` and `clang`, `gdb`; `CMake`: full
support, `cmake-language-server`).

**`init.el`**: added `(cc +lsp)` to `:lang` and `(format +onsave)` to
`:editor` (the latter was previously absent entirely — no language in this
image had a formatter wired until now). `config.el` gained two `load!`
calls (`c-keybindings`, `cmake-keybindings`).

**Dockerfile additions**:
- `clang`, `clangd`, `clang-format`, `gdb`, `cmake`, `ninja-build`, `g++`
  (`gcc` was already present, pulled in earlier for tree-sitter grammar
  compilation). `ccls` deliberately excluded — no apt package, no prebuilt
  release binary, and building it from source against a matching `libclang`
  would be real fragility for a server Doom's own `:lang cc` module already
  deprioritizes below clangd.
- `cmake-language-server` 0.1.11 via `pipx`. Its own repo has been
  unmaintained since Jan 2025 and declares `requires-python <3.14`, which
  this Ubuntu release's system Python fails outright — confirmed live in a
  throwaway container, not assumed. `--ignore-requires-python` installs it
  anyway, but its loose `pygls>=1.1.1` constraint then resolves pygls 2.x,
  which removed `LanguageServer` from `pygls.server` as a breaking change
  (confirmed live via the resulting `ImportError`, not just an
  overcautious version cap). `pipx inject cmake-language-server
  pygls==1.3.1 --force` pins back to the last 1.x release; `--version`
  confirmed working with this combination before committing to it.
- `vcpkg` (2026.06.24) and `conan` (2.30.0) added as the C/C++ package
  managers — no equivalent existed for this language pair before. `vcpkg`
  has no apt package or standalone release binary for the tool itself (it's
  meant to live as a clone alongside your projects); cloned to a stable path
  and bootstrapped instead, falling back to source compile if no prebuilt
  `vcpkg-tool` release matches the arch (needs `cmake`/`ninja-build`/`g++`,
  already installed). `conan` installed cleanly via `pipx` with no
  workarounds needed. `zip` added to the apt list as a `vcpkg` bootstrap
  prerequisite.
- `nupm` (nushell's own package manager, pinned to commit `9a28419`) added
  in the same pass — bundled here because it's the same "give every
  language that has a package manager one" motivation as vcpkg/Conan, not
  because it's C-specific. It has no apt/pip/tagged-release path at all: a
  self-hosted Nushell module you clone and `use`, explicitly marked
  "experimentation stage" by its own maintainers. Confirmed live in a
  throwaway container that the pinned commit bootstraps and installs
  packages correctly before committing to it. Found and fixed one install-path
  gotcha live: `nupm install <path> --path` needs `<path>` to be the
  directory directly containing `nupm.nuon`, not a bare relative name — the
  project's own README self-install example only works by coincidence when
  the checkout happens to be cloned into a directory literally named
  `nupm`. Only `nupm` itself is baked in; specific packages it installs
  (`nutest`, etc.) belong to whichever project needs them.

**Two bugs found and fixed, both via live testing rather than assumed
correct from the config alone:**

1. Opening a lone `.h` file lsp-mode hadn't seen before blocked forever on
   a synchronous "import project?" minibuffer prompt — and because Emacs
   is single-threaded, that wedges *every* emacsclient connection, not just
   the one that opened the file. Fixed with `(setq lsp-auto-guess-root t)`
   in `config.el`'s existing `after! lsp-mode` block.
2. `:editor format` was missing entirely, so `clang-format` wasn't
   installed and indentation was never touched — not a linter gap
   (`clangd` diagnostics are compile-level: syntax/type/warnings, never
   whitespace) but a missing formatter. Fixed by adding `clang-format` to
   the Dockerfile and enabling `(format +onsave)` in `init.el`. Confirmed
   compiler-agnostic: `clang-format`/`clangd` parse with their own
   frontend rather than invoking `gcc`/`clang` to build, so this works
   identically for gcc-built projects.

**Testing**: `smoketest.bats` gained mode-activation checks for
`.c`/`.cpp`/`.h`/`.mm`/`CMakeLists.txt`, LSP-load checks for `c-mode` and
`cmake-mode`, localleader keybinding checks (`c-keybindings.el`'s
format-buffer binding; `cmake-keybindings.el`'s new `+cmake/configure`/
`+cmake/build` commands, invoking `cmake -B build -S .` / `cmake --build
build` via `compile` — later renamed from bare `cmake-configure`/`cmake-build`
to the `+cmake/` prefix, and later still joined by `+cmake/rebuild`/
`+cmake/clean`; see this file's entries below), and tool-version checks for
`clang`/`clangd`/`gcc`/
`g++`/`cmake`/`gdb`/`cmake-language-server`/`vcpkg`/`conan` (40 total
`@test` cases now, up from 25). A manual debug project
(`flight-tests/c/`: `main.c`/`greet.c`/`greet.h` behind a small
`CMakeLists.txt`) was used for live container testing of both bugs above
before they were confirmed fixed via `smoketest.bats`. Both fixes and all
Dockerfile/`packages.el`-adjacent additions applied to the aarch64 tree in
lockstep, matching this project's established convention.

**Outstanding at the time this entry was first written**: the debugger half
of "full support" looked unwired. That assumption was wrong — corrected
immediately below, same day. Not yet committed to git either; these
changes (both trees) are still sitting as uncommitted working-tree
modifications.

---

#### Follow-up, same day: C debugger support was already fully wired

Went looking for how to wire `gdb` into the IDE (the gap noted just above)
and found there was nothing left to do. The original project plan (this
file's own "Language stack decisions" section, written 2026-05-06) says
"Debugger: `gdb` via dap-mode" — but that's stale: Doom's `:tools debugger`
module doesn't use `dap-mode`/`dap-utils`/vsix-downloaded VS Code extensions
at all anymore. Read the module's actual source at this project's pinned
Doom commit (`4e0dbb9`, `modules/tools/debugger/{config,packages}.el` and
`README.org`, fetched directly via `gh api` rather than assumed from
memory of an older Doom): it installs
[`dape`](https://github.com/svaante/dape) (pinned commit `48b3db3`), a
pure-Elisp DAP client with no VS Code extension dependency.

`dape`'s own source (`dape-configs`, also read directly rather than
assumed) ships a **built-in `gdb` template already covering
`c-mode`/`c-ts-mode`/`c++-mode`/`c++-ts-mode`** (plus Go and Hare), driven by
GDB's own native `--interpreter=dap` support (GDB ≥ 14.1, no separate
adapter binary, no Node.js, nothing to download) — exactly the `gdb`
binary already installed in this Dockerfile for the earlier C/CMake work.
Its `ensure` function runs `gdb --version` and throws `user-error` below
14.1; checked the actual apt-resolved version against the real archive
index rather than assuming — resolute/arm64 ships `gdb` 17.1-2ubuntu1,
noble/amd64 ships 15.0.50, both comfortably clear.

Separately, `:config (default +bindings)` (also already enabled in
`init.el`, present since project start) turned out to already bind a full
`SPC d ...` global prefix to every `dape` command that exists —
start/pause/continue/next/step-in/step-out/restart, breakpoint
toggle/log/expression/hits/remove-all, thread/stack select, watch,
evaluate, disconnect, quit — read directly from Doom's
`modules/config/default/+evil-bindings.el` at the pinned commit rather
than assumed present. `+debugger/start` (bound to `SPC d d` and also `SPC
o d`) is a plain `defalias` for `dape` itself.

Net result: no Dockerfile change, no `config.el`/`init.el` `:lang`/`:tools`
change, no new keybinding file — every piece (module, package, gdb binary,
global keybindings) was already in place before this session started.
Only one real fix made: `init.el`'s `(debugger +lsp)` dropped the stray
`+lsp` flag — the module's own `README.org` states "This module has no
flags," so the flag was inert dead syntax, not a meaningful toggle.

Added `smoketest.bats` coverage to turn this finding into a regression
guard rather than leaving it as an unverified read of upstream source: a
`gdb --version` major-version floor check (`>= 14`), a check that
`dape-configs`' `gdb` entry's `modes` list actually contains `c-mode` and
`c++-mode`, and a check that `SPC d d` resolves to `dape` in a `c-mode`
buffer. 43 `@test` cases now (was 40).

**Not verified**: an actual live debug session (compile with `-g`, `SPC d
d`, select the `gdb` config, hit a breakpoint) was not run end-to-end —
this environment has no docker/container access, same limitation noted
throughout this log. The smoketest additions confirm every piece is
correctly *wired*, not that a real GDB DAP handshake succeeds inside the
container; that's the one thing still worth Josiah confirming live.

---

#### `cmake-keybindings.el`: rebuild/delete-build bindings, then a style-guide pass

Josiah noticed `+cmake/build`'s incremental Make cache was hiding a
compiler warning (an unused variable) during flight-test iteration — the
prompting incident. Added two more localleader commands alongside the
existing configure/build pair: `SPC m b r` (`cmake --build build
--clean-first`, forces every file to recompile) and `SPC m b d` (`rm -rf
build`, full teardown — distinct from `--clean-first`, which only clears
compiled objects via the underlying build tool and leaves `CMakeCache.txt`
and the rest of the generated build system in place).

Josiah then asked for a review of this file (and the day's other changes)
against `ELISP-STYLE-GUIDE.md`/`ELISP-ARCHITECTURE-GUIDE.md`/
`DOOM-EMACS-GUIDE.md`, DRY, and general Doom/elisp convention. Two real
findings survived scrutiny, both fixed:

1. **Naming.** The original `cmake-configure`/`cmake-build` (and the two
   just added, matching that existing local pattern) were bare `cmake-*`
   names with no project namespace — a direct violation of this file's own
   `ELISP-STYLE-GUIDE.md` §3.2 ("every top-level symbol gets a prefix"),
   and inconsistent with the Doom-idiomatic `+module/name` convention
   already used elsewhere in this exact project (`go-keybindings.el`'s
   `+go/playground-yank`). Renamed to `+cmake/configure`, `+cmake/build`,
   `+cmake/rebuild`, `+cmake/clean`.

2. **Project-root anchoring.** All four commands ran `compile` against
   whatever `default-directory` happened to be — correct only when
   invoked from a buffer visiting the *top-level* `CMakeLists.txt`. A
   nested subdirectory `CMakeLists.txt` (an `add_subdirectory()` target)
   would build or `rm -rf` a `build/` in the wrong place. The first fix
   considered — `projectile-project-root` — was checked against this
   project's own `flight-tests/c/` before adopting it, and turned out to
   be actively wrong: that directory has no `.git` of its own, so
   `projectile-project-root` resolves to the *outer* `docker-emacs` repo
   root (no top-level `CMakeLists.txt` there at all), which would make
   `+cmake/clean`'s `rm -rf build` run with a far larger and wrong blast
   radius than the bug being fixed. Wrote `+cmake--root` instead: walks
   upward via `locate-dominating-file` past every nested `CMakeLists.txt`
   until no further ancestor has one, landing on the outermost project
   directory with no VCS dependency at all. All four commands now
   `let`-bind `default-directory` to `(+cmake--root)` around the `compile`
   call.

`smoketest.bats`'s keybinding-resolution test updated to match the
renamed symbols and now checks all four bindings (was two); still 43
`@test` cases (renames don't add tests). Also caught and fixed, while
reviewing: this tree's copy of that same test had silently fallen out of
lockstep — it still only checked configure/build even after the aarch64
tree gained rebuild/clean coverage in the debugger-review pass above.
Both trees now match exactly.

---

#### Docker and Podman support: bridge the host's engines, don't run a second one

Motivated by the FaradAI sandbox project, which manages its own containers
on the host. `docker`/`podman` were both entirely absent before this (no
`:tools docker` customization beyond the bare module, no podman anywhere).

**Design decision, made explicit before any code**: don't install a second
`dockerd`/podman storage backend inside this image at all. Container
image/volume storage is often many GB; running an independent engine
inside the IDE container would mean duplicating that storage rather than
sharing it. Instead, install only the **client** binaries (`docker.io`,
`podman` — both confirmed present in `universe` on both distros via the
real archive index, same verification standard as every other package
here: `docker.io` 29.1.3 on resolute/arm64, 24.0.7 on noble/amd64; `podman`
5.7.0 on resolute/arm64, 4.9.3 on noble/amd64 — versions differ across
distros and were left unpinned, matching how `clang`/`cmake`/`gdb` are
already handled) and bridge each client to the **host's** real engine over
its API socket, exactly the way `run.sh` already bridges Nix.

**Chose not to reuse the Nix bridge's approach.** That bridge exists
because a Nix store is already a portable, content-addressed artifact —
sharing it avoids a second copy of the *same* reproducible thing, and
needed real complexity to pull off (`ldd`-based library rediscovery every
launch, a `LD_LIBRARY_PATH`-scoped wrapper script, Fedora-vs-Ubuntu ABI
reconciliation). Docker and Podman don't need any of that: both engines
expose a documented, purpose-built remote API over a Unix socket
specifically so a thin client elsewhere can talk to them — a real
client/server boundary, not a filesystem store being creatively
relocated. Bridging the socket is the intended, supported way to do this,
not a workaround.

**Docker**: rootful, single system-wide `docker.service`, socket at the
fixed path `/var/run/docker.sock`, owned `root:docker` with group-rw
permissions (confirmed against the host directly rather than assumed).
Bind-mounted at the identical path — the Docker CLI's own default lookup
path, so no `DOCKER_HOST` env var is needed at all. The socket's group
ownership is the one real wrinkle: the container's runtime user needs
supplementary membership in a group matching that GID to access it
without root. Resolved with `docker run --group-add
"$(stat -c '%g' /var/run/docker.sock)"` at container-start time (`run.sh`)
rather than baking a specific GID into the image — the GID can differ
per host, and this is Docker's own documented pattern for exactly this
situation (the standard "mount the docker socket" DooD — Docker-outside-
of-Docker — approach used by most CI runners).

**Podman**: rootless, per-user `podman.socket` (a systemd *user* unit,
confirmed **not enabled by default** even though `podman` itself was
already installed on the reference host — `systemctl --user enable --now
podman.socket` was required and run directly against it as part of this
session, since nothing works without it). Socket lives at
`$XDG_RUNTIME_DIR/podman/podman.sock`, owned directly by the invoking
user — no group trick needed, unlike Docker's rootful model.
**Podman's remote mode is not optional the way it might look**: unlike
the Docker CLI (always a thin client, no other mode exists), the `podman`
CLI defaults to managing *local* storage directly whenever no
`CONTAINER_HOST`/`--remote` is set — with no local podman storage
configured in this image on purpose, an unset `CONTAINER_HOST` wouldn't
fail loudly, it would silently start building a redundant, broken local
store inside the container instead of ever reaching the host. Confirmed
this distinction directly rather than assuming Podman's API-socket
behavior mirrors Docker's.

**This port needed one adjustment the aarch64 port didn't.** aarch64's
`run.sh` already bind-mounts the entire `XDG_RUNTIME_DIR` unconditionally
(for Wayland), so its podman socket needs no dedicated `-v` at all once
the host service is active — just the `CONTAINER_HOST` env var. This
port's `run.sh` has no such mount at all (X11/`DISPLAY` here, not
Wayland), so the podman socket is bind-mounted explicitly by its own
specific path instead. Both ports gained a `MOUNT_HOST_DOCKER`/
`MOUNT_HOST_PODMAN` escape hatch each (default on), mirroring
`MOUNT_HOST_NIX`'s existing shape, plus an informational `stderr` warning
when either socket is missing — deliberately not silent like the Nix
mount's bare `if`, since "you forgot to `systemctl --user enable
podman.socket`" is an easy, easy-to-miss trap worth surfacing at
container-launch time rather than as a confusing error from inside Emacs
later.

**Doom/config.el side turned out to need almost nothing.** `dockerfile-mode`
(from the already-enabled `:tools docker` module) already matches
`Containerfile` in its own `auto-mode-alist` entry — confirmed directly
from source rather than assumed, so no new mode-alist wiring was needed
for Podman's preferred naming. `docker.el`'s `M-x docker` tabulated
management UI is already bound to `SPC o D` by Doom's own `:config default`
the moment `:tools docker` is enabled — also confirmed directly from
`+evil-bindings.el` rather than assumed, so no new binding was needed to
launch it either. The one real gap: `docker.el` only targets **one**
backend at a time via the `docker-command` variable (default `"docker"`,
left untouched), and there's no built-in way to view both docker and
podman through the same UI simultaneously — so the only new elisp
written is a small toggle, `docker-keybindings.el`'s `+docker/toggle-engine`
(`SPC o c`, flips `docker-command` between `"docker"`/`"podman"`). Checked
the full `SPC o` ("open") prefix-map in `+evil-bindings.el` directly before
picking `"c"` — `"e"`/`"E"` are already claimed by eshell (also enabled in
this project), which a guess would have silently collided with.

**Testing**: `smoketest.bats` gained a `docker --version`/`podman
--version` install check, a check that `SPC o D` resolves to `docker`, and
a check that `SPC o c` actually flips `docker-command` from `"docker"` to
`"podman"` when invoked. 46 `@test` cases now (was 43). The actual
socket-bridge behavior (whether the in-container `docker ps`/`podman ps`
really reaches the host's containers) can't be exercised by the bare
`bats smoketest.bats` invocation — same limitation as Nix's live
functionality, which also only gets a version/package-existence check
here and its real behavior verified via `nix-smoketest.bats` under
`run.sh`'s actual mounts. Not yet verified end-to-end against a live
rebuilt image — the actual `docker build` + `run.sh` cycle wasn't run
this session, only the host prerequisites (package availability, socket
paths/permissions, `podman.socket` enablement) were checked directly
against the aarch64 host; pending Josiah's rebuild and retest on this
port specifically.

---

#### Bug: `SPC m e b` on `run.sh` failed with `/bin/sh: [[: not found`

Rebuilt aarch64 image confirmed the docker/podman bridge works (`SPC o D`
showed real host containers). Separately, Josiah hit `sh-execute-region`
("Execute buffer", `SPC m e b`) failing on `run.sh` itself with `/bin/sh:
9: [[: not found` — a dash-only failure, not a bash one, even though
`run.sh` is `#!/usr/bin/env bash` and its modeline correctly showed the
bash dialect.

Root cause isolated by reading `sh-script.el` directly (installed source,
not assumed): `sh-execute-region`'s docstring says plainly "The executed
subshell is `sh-shell-file`" — but `sh-set-shell` only *updates*
`sh-shell-file` when called with a non-nil `insert-flag` (its third arg),
which happens only when a shebang line is being interactively
rewritten. The automatic dialect detection that runs for every
`sh-mode`/`bash-mode`/`zsh-mode`/`ksh-mode` buffer calls exactly
`(sh-set-shell (sh--guess-shell) nil nil)` — `insert-flag` nil — so
`sh-shell-file` never gets touched and stays at its global default
(`/bin/sh`, i.e. dash on this image) regardless of what `sh-shell` was
correctly detected as. `sh-shell` itself *is* reliably correct (confirmed
`sh--guess-shell` reads the buffer's own shebang line directly) — this is
purely a `sh-shell-file`-never-synced bug, present in vanilla
`sh-script.el` itself, not something introduced by this project's own
config. It would have affected `SPC m e e`/`SPC m e b` for **any**
bash-only script in this project (including files opened through this
project's own `bash-mode`/`zsh-mode`/`ksh-mode`, since those also call
`sh-set-shell` with a bare single argument) — just never actually
exercised until now, since the existing smoketest only checks that these
keybindings *resolve* to the right function, not that invoking them
actually executes correctly.

Fixed at the root in `shell-config.el`: `+shell--sync-shell-file`, hooked
onto `sh-mode-hook` (which fires for `bash-mode`/`zsh-mode`/`ksh-mode`
too, since they derive from `sh-mode` and Emacs runs all ancestor mode
hooks on activation), sets buffer-local `sh-shell-file` to
`(symbol-name sh-shell)` — mirroring the value that's already correctly
detected rather than reimplementing detection. Confirmed hook ordering is
safe by reading `sh-mode`'s own body directly: `(sh-set-shell
(sh--guess-shell) nil nil)` runs as part of the mode's own setup, which
completes before `run-mode-hooks` fires, so `sh-shell` is always already
correct by the time this hook runs.

**Testing**: added a `test-shebang.sh` fixture (`#!/usr/bin/env bash`,
deliberately no `.bash` extension, to exercise plain `sh-mode`'s shebang-
only detection path rather than this project's own extension-driven
`bash-mode`) and a test asserting both `sh-shell` and `sh-shell-file`
report `"bash"` after opening it. 47 `@test` cases now (was 46). Confirmed
via `emacs-lisp-mode`'s `check-parens` (not `fundamental-mode`'s — a
first attempt there false-flagged on ordinary apostrophes in comments,
since `fundamental-mode` has no syntax table telling it `'` isn't a
string delimiter) that `shell-config.el` still parses cleanly in both
ports. Not yet verified live against a rebuilt image on this port;
pending Josiah's rebuild.

---

#### `run.sh`: inject the host's environment (not its dotfiles)

Prompted by the `sh-shell-file` bug above: Josiah's real question was
broader — for a script exercised via Emacs keybindings/M-x
(`sh-execute-region`, `compile`, `async-shell-command`) to behave the way
it would on the real host, doesn't the container need pieces of the
host's environment (his examples: `SSH_AUTH_SOCK`, `USER`, `HOME`, as
things he assumed came from `.bashrc`)?

First pass at this (mounting `.bashrc`/`.zshrc`/nushell dotfiles,
mirroring the existing `.gitconfig`/`.ssh` read-only mount pattern) turned
out to be solving a different problem than the one being asked. Checked
directly against the aarch64 host rather than assumed: `HOME`/`USER` are
not set by any dotfile at all (grepped `.bashrc`/`.profile`/`.zshrc`/
`.zshenv`/`.zprofile` — zero exports; `loginctl` confirms these come from
the login/session layer, before any rc file runs). `SSH_AUTH_SOCK`
genuinely *is* shell-managed there (the systemd `ssh-agent.socket` unit
is loaded but inactive; the real agent socket lives at a path referenced
directly in `.zshrc`'s tmux-agent-reuse logic) — but that distinction
doesn't matter for the actual question, because `sh-execute-region`/
`compile` are **non-interactive** invocations, and non-interactive shells
don't source `.bashrc`/`.zshrc` even on the real host. Mounting the
dotfiles wouldn't have reached this case at all, regardless of which
variables happen to live in them on any given machine.

Reframed once Josiah named the actual point explicitly: this container's
job is a reproducible, stable *tooling* environment, not a sandbox — so
the fix isn't per-variable archaeology (`.bashrc` vs login vs systemd
unit), it's capturing the calling shell's already-fully-resolved
environment (already dotfile-sourced, since `run.sh` itself always runs
inside an interactive host shell) and threading it straight into the
container as `-e` flags at the one point the boundary actually is —
container launch — rather than trying to re-derive it inside the
container per shell dialect.

**The one real tension, and it's the interesting part**: blind
wholesale injection would work against the container's own stated
purpose. `PATH`/`LD_LIBRARY_PATH`/`MANPATH`/`PYTHONPATH` describe *how to
find binaries*; overriding them with the host's own values would
reintroduce exactly the version drift this image exists to prevent —
trading fidelity to the host's *scripts* for breaking fidelity to the
image's own *toolchain*. So the design excludes those, plus anything
this script already bridges deliberately to a **different** value than
the raw host one (`SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`,
`GDK_BACKEND`, `DISPLAY` — a blanket pass-through would otherwise race
against the specific remapping already in place for each), `HOME`/`USER`
(already correct by construction — the container's own user is built at
image-build time to mirror the host username), and shell-instance-
mechanical variables that are either meaningless or actively wrong
carried into a different process/directory (`PWD`, `OLDPWD`, `SHLVL`,
`TERM`, `_`).

Implementation: `env -0` (NUL-separated, safe against embedded newlines
in values) piped through a `while` loop matching each key against a
regex exclusion list, building a `host_env` array of `-e KEY=value`
pairs exactly like every other conditional mount block in this file.
`INJECT_HOST_ENV=0` disables it entirely, matching the
`MOUNT_HOST_NIX`/`MOUNT_HOST_DOCKER`/`MOUNT_HOST_PODMAN` escape-hatch
convention already established here.

**Explicitly out of scope, and worth being precise about why**: this
covers *variables* only. Aliases and shell functions aren't part of the
process environment at all (bash can export functions via a special
encoding; zsh has no equivalent mechanism), so neither survives this
mechanism regardless — they only exist if a real interactive shell
actually sources the rc file, which is a `vterm`-opened-a-real-shell
concern, genuinely separate from the M-x/keybinding-execution problem
this solves. Josiah's own plan for that gap: a separate git-pullable
library of Bash/Zsh/Nushell functions, versioned and cloned in as a
dependency rather than baked into image config — reasonable, and not
something this session needed to build.

**Tested standalone** (not yet inside a rebuilt container): ran the
capture loop directly against the aarch64 host's real shell environment
— 83 of 166 total variables passed the exclusion filter; confirmed by
name that `PATH`, `HOME`, `USER`, `SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`, and
`TERM` are all correctly absent from the captured set. Not yet verified
end-to-end against a live rebuild on this port; pending Josiah's
rebuild.

---

#### Lua added as a seventh full-support language

Following a design discussion about scope: systems-ide isn't meant to be
a weaker `python-doom-emacs-ide`-style application-development IDE for
these languages, it's meant to be tailored to how a systems engineer
actually encounters them — isolated config/glue scripts embedded in
someone else's project, not a project of systems-ide's own. Lua gets
**full** support rather than the glue-script tier, though, matching the
original project plan's own reasoning (`README.md`'s new "Language
grouping philosophy" section, added this session, documents this split):
Lua configuration in window managers/Neovim/Redis/nginx is deep and
non-trivial enough that syntax-only would leave real value on the table.

**Doom's own `:lang lua +lsp` module does almost all of the work.**
Confirmed by reading it directly rather than assumed: it already wires
`lua-mode`'s interpreter detection (`\<lua(?:jit)?`), a REPL via
`set-repl-handler!` (reachable through `:tools eval`'s global `M-r` →
`+eval/buffer`, no custom binding needed), automatic LSP attachment via
the mode's own local-vars-hook once `+lsp` is enabled, and — per Doom's
own module README — format-on-save via StyLua through the already-active
`:editor format` module. `lua-keybindings.el` ended up needing almost no
custom code: one on-demand `lsp-format-buffer` binding (`SPC m f`),
matching `c-keybindings.el`'s exact same rationale (format-on-save
existing doesn't make an on-demand format command redundant), plus a
Commentary block documenting what Doom already provides for free.

**Two binaries needed manual installation, one interpreter from apt:**
- `lua5.4` (apt, both distros — `5.4.8-1build1` resolute/arm64,
  `5.4.6-3build2` noble/amd64). No bare `lua` symlink ships with Debian's
  versioned lua packages (deliberate, so multiple versions can coexist);
  `lua-mode`'s own interpreter-detection regex expects a bare `lua`/
  `luajit` name, so one is created explicitly
  (`ln -s /usr/bin/lua5.4 /usr/local/bin/lua`).
- `lua-language-server` 3.18.2, prebuilt Linux release binaries (arm64/
  x64), SHA256 computed directly from the downloaded artifacts rather
  than trusted from an upstream checksum file — neither this release nor
  StyLua's publishes one, unlike Go's/NFM's already-published hashes
  elsewhere in this Dockerfile. Ships as a whole directory tree (`bin/`,
  `locale/`, `main.lua`, ...), not a single relocatable binary — confirmed
  from the actual tarball listing before assuming a single-binary
  `install -m 755` copy (the pattern used for Go/NFM) would work; it
  wouldn't have, `bin/lua-language-server` depends on the sibling
  `main.lua`/`locale/` paths at fixed relative locations, so the whole
  archive is extracted intact to `/usr/local/lib/lua-language-server/`.
- `stylua` 2.5.2, prebuilt Linux release binary (aarch64/x86_64, non-musl
  variant matching Ubuntu's glibc rather than the musl build meant for
  Alpine). Single self-contained Rust binary — no Rust toolchain needed
  to install it, same reasoning as `nu`'s own prebuilt-tarball install.

**`lsp-clients-lua-language-server-bin` set explicitly in `config.el`**
rather than relying on `lsp-mode`'s own default install-directory
convention. Checked `lsp-mode`'s actual source for this rather than
trusting Doom's `:lang lua` module README, which describes an older
`$EMACSDIR/.local/etc/lsp/` convention — current `lsp-mode` (`clients/
lsp-lua.el`, `lsp-mode.el`) actually defaults to `$EMACSDIR/.cache/lsp/`,
a real, confirmed discrepancy between the README's documentation and the
actual dependency's current behavior. Rather than gamble on which
default is correct for the pinned Doom/lsp-mode commit this project
actually uses, the binary is installed to a fixed path this project
controls entirely (`/usr/local/lib/lua-language-server/bin/lua-language-
server`) and pointed at explicitly — the same "don't bet on a moving
default, be explicit" reasoning already applied to `lsp-auto-guess-root`
and `docker-command` elsewhere in this same file.

**Testing**: `smoketest.bats` gained a `test.lua` fixture, an install
check for all three tools (asserting the pinned `lua-language-server`/
`stylua` versions specifically, matching the regression-guard convention
already used for `gopls`/`dlv`/`golangci-lint`), `.lua` → `lua-mode`
activation, an LSP-load check, and the format-buffer keybinding
resolution check. 51 `@test` cases now (was 47), matching the aarch64
port exactly. Confirmed every `.el` file touched this session
(`config.el`, `init.el`, `lua-keybindings.el`) parses cleanly via
`emacs-lisp-mode`'s `check-parens`. Confirmed `lua-keybindings.el`
already had its Dockerfile `COPY` line (it's a placeholder scaffolded at
project start, unlike `docker-keybindings.el` earlier this session,
which was newly created and genuinely missing one) — checked directly
rather than assumed, after getting burned by exactly that gap once
already on the aarch64 port.

**Bug found on the aarch64 port's first real build attempt: `ln:
Permission denied`** on the `lua` symlink step. All three lua install
`RUN` steps were placed after `USER ${USERNAME}` — this Dockerfile
switches to the non-root runtime user partway through, and everything
after that point only has write access within its own `$HOME`.
`/usr/local/bin`/`/usr/local/lib` are root-owned; the apt packages and
the Go tarball earlier in this file never hit this because they run
*before* the `USER` switch, as root. `vcpkg`/`conan`/`nupm`, added the
same session as the C/CMake work, already follow the correct pattern
(installed under `/home/${USERNAME}/...`) — the lua steps were the one
exception, added without checking where they'd land relative to that
switch. Fixed by moving all three installs under the runtime user's own
`~/.local/` (`~/.local/bin/lua`, `~/.local/bin/stylua`, `~/.local/lib/
lua-language-server/`) — `~/.local/bin` was already on `PATH`, so no new
`PATH` entry was needed. `config.el`'s `lsp-clients-lua-language-server-
bin` and `smoketest.bats`'s version check both updated to match, using
`(expand-file-name "~/...")`/`$HOME` respectively rather than a literal
username, so neither depends on the runtime user's exact name. Applied
here in lockstep with the aarch64 fix. Not yet verified end-to-end
against a rebuild on this port; pending Josiah's build attempt here.

---

#### Python, Ruby, and JavaScript added as a glue-script tier — LSP on, project tooling off

Design discussion landed on a real distinction from the original plan:
these three (plus the still-unbuilt Ruby/Perl/Fish/Assembly batch) were
originally slated "syntax only, no LSP" — but LSP's actual value doesn't
depend on having a project. Modern language servers handle a lone file in
an inferred single-file project just fine for anything within the
standard library, which is most of what a systems-context script actually
is (Ruby for Chef recipes, not Rails; Python for WM/DE config scripting
and one-off Fabric tasks, not framework development). What breaks without
a project is narrower than "everything" — just resolution of actual
third-party imports. So: LSP on for all three, but deliberately **no**
pip/poetry/conda, no bundler/rvm/rbenv/chruby, no node_modules-based
tooling — scoped to editing/linting isolated scripts, never to developing
applications in these languages (a job this project already has a
separate dedicated IDE for, per `python-doom-emacs-ide` in the root
`README.md`'s image table — `README.md`'s new "Language grouping
philosophy" section, written this session, documents the full
reasoning).

Linters and formatters were explicitly back in scope this time (a
correction from the original syntax-only plan, which had neither) —
Josiah's framing: "style and discipline are always important even for
just scripting."

**Python**: `(python +lsp +pyright)`. `pyright` chosen over the newer
`ty` (also supported by lsp-mode via `clients/lsp-python-ty.el`, and
listed first/"recommended" in Doom's own module README) — `ty-ls` is
registered `:add-on? t`, meaning it runs *alongside* a primary client
rather than replacing one, so it wouldn't have been sufficient alone
regardless; `pyright` is the long-established, single, well-supported
choice, matching this project's repeated preference for one mature tool
over a newer one still establishing itself (clangd over ccls, `ty` not
pursued for the same reason). Installed via `npm install -g
pyright@1.1.411`, matching `bash-language-server`'s existing install
shape exactly.

`ruff` handles both linting (flycheck's built-in `python-ruff` checker —
confirmed directly from flycheck's own source that this checker's
`--config` flag uses flycheck's `config-file` cell type, meaning it's
simply omitted when no `pyproject.toml`/`ruff.toml` is found rather than
erroring, so it's genuinely zero-config-capable) and formatting
(overriding apheleia's own default of `black` for `python-mode`).
Considered installing `black` instead (apheleia's default, zero override
needed) — Josiah's call after discussing the tradeoff: `ruff format` is
explicitly built to match Black's own output, so the actual formatted
result is nearly identical either way; the reason to prefer `ruff` is
purely that it's already required for linting, so using it for both
avoids installing a second, unrelated tool via `pipx` for formatting
alone. `ruff format`'s configurability was checked directly against its
live JSON schema rather than assumed (`quote-style`, `skip-magic-trailing-
comma`, `indent-style`, `indent-width`, `line-ending`, `docstring-code-
format`, `preview` are the real, current knobs) — genuinely more
configurable than Black, though still deliberately opinionated by design,
not sprawling like Prettier/clang-format.

Ruff's own docs were checked (not assumed) for a **user-level config**
mechanism, since the whole point here is style preferences applying to a
lone script with no project file of its own: `${config_dir}/ruff/
pyproject.toml` (on Linux, XDG-style, via the `etcetera` crate's base
strategy) is used whenever no project-level config is found in the
directory hierarchy — and a real project's own config still takes
precedence automatically if one ever exists. Baked in as
`ruff-pyproject.toml`, `COPY`'d to exactly that path, encoding Josiah's
actual style decisions from this session's discussion: 2-space indents,
LF line endings, docstring code formatting on, no preview features
("systems programmers should optimize for stability"), and — after
initially discussing disabling it — magic trailing comma left **on**
("if I want everything on one line, I can just delete that comma, and
the pattern then is consistent").

**Ruby**: `(ruby +lsp)`, no `+rails`/`+rvm`/`+rbenv`/`+chruby`. `ruby-lsp`
(Shopify's, the actively-maintained modern choice) over `solargraph` —
confirmed via `lsp-mode`'s own `lsp-ruby-lsp.el` that `lsp-ruby-lsp-use-
bundler` defaults to `nil`, so it runs as plain `ruby-lsp` with no
Gemfile/bundler involvement at all, matching this tier's scope exactly;
solargraph isn't installed, so there's no ambiguity between the two for
lsp-mode to resolve. Both `ruby-lsp` and `rubocop` installed via global
`gem install --no-document` (no bundler). `rubocop` handles both linting
(flycheck's built-in `ruby-rubocop` checker, same zero-config-friendly
`config-file`-cell pattern as `python-ruff`) and formatting (`rubocop -a`,
overriding apheleia's own default of `prettier-ruby` for `ruby-mode` —
checked directly and confirmed apheleia's default surprisingly pulls in
an npm-based `@prettier/plugin-ruby`, a whole separate JS toolchain, just
to format Ruby; `rubocop` avoids that entirely, one Ruby-native tool
already needed for linting doing both jobs).

**JavaScript**: `(javascript +lsp)`, wired to `typescript-language-server`
+ its `typescript` peer (not `deno`, the module's other supported
server), both via npm, matching the existing `bash-language-server`
install shape. Linting deliberately uses `oxlint`, not `eslint` — checked
flycheck's own two checker definitions directly: `javascript-eslint` has
a dedicated `flycheck--eslint-handle-suspicious` code path specifically
for the "no config found" case (confirming this is a known, expected
friction point, not an edge case), while `javascript-oxlint`'s `:command`
is just `oxlint --format checkstyle <file>` with no config-file handling
at all — genuinely zero-config, the same role `ruff`/`rubocop` play for
their languages. `eslint` isn't installed, so there's no checker
ambiguity for flycheck to resolve. Formatting uses apheleia's own
existing default (`prettier`) for `js-mode`, unchanged — no override
needed, unlike Python/Ruby.

**Design inconsistency found and *not* fixed, on purpose, out of
scope**: `c-keybindings.el`/`lua-keybindings.el`'s on-demand format
binding calls `lsp-format-buffer` (the LSP server's own formatting
capability), while `python-keybindings.el`/`ruby-keybindings.el`/
`javascript-keybindings.el` (written this session) call
`apheleia-format-buffer` directly instead. `pyright` does not implement
LSP-level document formatting at all (confirmed by the fact that
`python-mode` needs its own independent apheleia formatter mapping
regardless of LSP server choice — if pyright formatted, this wouldn't be
necessary), so `lsp-format-buffer` would have been a silent no-op for
Python specifically; using `apheleia-format-buffer` uniformly for the
three new languages also guarantees the on-demand and on-save paths
always use the *identical* formatter, which isn't strictly guaranteed by
the older `lsp-format-buffer` pattern (clangd/lua-language-server happen
to agree with clang-format/stylua's output, but that's coincidence, not a
guarantee). Reconciling `c-keybindings.el`/`lua-keybindings.el` to the
same pattern is a reasonable future cleanup, deliberately not done here.

**Bug found on the aarch64 port's build attempt: `rubocop:1.81.9`
doesn't exist.** `gem install --no-document ruby-lsp:0.24.1
rubocop:1.81.9` failed with `ERROR: Could not find a valid gem 'rubocop'
(= 1.81.9)`. Every other version pin this session (`pyright`,
`typescript-language-server`, `typescript`, `prettier`, `oxlint` via the
npm registry API; `ruff`, `lua-language-server`, `stylua` via the GitHub
releases API) was checked against a real registry before being written
down — this one wasn't, a real lapse (see `[[feedback_verify_pkgs_before_
build]]`, updated this session to note the recurrence). Checked
rubygems.org's own API directly: the real current version is `1.88.2`.
Fixed in both ports' Dockerfiles and `smoketest.bats`'s version
assertion, applied here in lockstep with the aarch64 fix.

**Testing**: `smoketest.bats` gained fixtures (`test.py`/`test.rb`/
`test.js`), tool-install checks for all nine new binaries/packages
(asserting pinned versions, matching the `gopls`/`dlv`/`golangci-lint`
regression-guard convention), mode-activation + LSP-load checks for all
three languages, format-buffer keybinding resolution checks, and a direct
check that `apheleia-mode-alist` actually resolves to `(ruff rubocop)`
for `(python-mode ruby-mode)` rather than trusting the `setf` calls
silently succeeded. 64 `@test` cases now (was 51), mirrored file-for-file
from the aarch64 port once its own `rubocop` version fix landed. Every
new/touched `.el` file (`config.el`, `init.el`, `python-keybindings.el`,
`ruby-keybindings.el`, `javascript-keybindings.el`) confirmed parsing via
`emacs-lisp-mode`'s `check-parens`; every `.el` file in the directory
re-confirmed to have a matching Dockerfile `COPY` line. Not yet verified
end-to-end against a live rebuild on this port; pending Josiah's build
here (the aarch64 port was being built in parallel while this mirror was
written).

#### Rust added as an eighth full-support language

Mirrored file-for-file from the aarch64 port (`Dockerfile`, `init.el`,
`config.el`, `rust-keybindings.el`, `flight-tests/rust/`,
`smoketest.bats`, `README.md`, `DECISIONLOG.md`) — same rationale applies
throughout (rustup pinned to `1.97.1` rather than apt, `rustic-mode` not
plain `rust-mode`, lldb over gdb for the debugger, `SPC m f` the only
addition to Doom's own already-extensive rustic-mode localleader map).
See the aarch64 tree's own BUILDLOG.md entry for the full reasoning.

**One real divergence, not just a mirror**: Ubuntu 24.04's plain `lldb`
apt package is LLVM 18.1.3 and ships neither `lldb-dap` nor `lldb-vscode`
at all — confirmed live in a throwaway `ubuntu:24.04` container, after
the aarch64 port's plain `lldb` (LLVM 21 there, ships `lldb-dap` directly)
made it seem like a non-issue. `lldb-20` is the oldest versioned package
available in 24.04's default repos that does ship it, but only as
`lldb-dap-20`, not the bare name dape's `lldb-dap` config expects —
symlinked to `/usr/local/bin/lldb-dap`, the same pattern this Dockerfile
already uses for `lua5.4` → `lua`. Documented in the apt-package comment
block rather than silently diverging from the aarch64 approach without
explanation.

**Not yet verified end-to-end against a live rebuild on this port**;
pending a build here (aarch64 was already rebuilding when this mirror was
written).

#### Follow-up: aarch64 live verification found three bugs, mirrored here unverified

Live testing against the rebuilt aarch64 image (see that tree's own
BUILDLOG.md follow-up entry for full detail) turned up three bugs missed
by the static review above:

1. `rust-keybindings.el`'s `after! rustic-mode` never fired (`rustic-
   mode` is the major-mode symbol, not the feature `rustic` `provide`s) —
   `SPC m f` was silently dead. Fixed: `after! rustic`.
2. dape's shared `gdb`/`lldb-dap`/`lldb-vscode` configs all hardcode
   `:program "a.out"` — a C-oriented placeholder, wrong for both cargo
   and this repo's CMake convention, and not Rust-specific (C/C++'s `gdb`
   config had the identical latent gap, never exercised before). Fixed
   with a shared `:program` resolver (`cargo build --message-format=json`
   for Rust, a `./build/` executable scan for CMake), extracted into its
   own cross-language `dape-config.el` rather than either language's
   keybindings file.
3. lldb-server hangs launching any binary at all on the aarch64 host,
   reproduced identically from the container's default privileges all the
   way up to full `--privileged` — ruling out a capability/seccomp
   restriction as the cause, root cause still unidentified. gdb works
   immediately at every privilege level on the same binaries. Decision:
   route c-mode/c++-mode/rust-mode/rustic-mode/rust-ts-mode through `gdb`
   exclusively; `lldb-dap`/`lldb-vscode`'s `modes` cleared so `SPC d d`
   doesn't offer a silently-hanging option. `lldb` package stays
   installed. Full reasoning in DECISIONLOG.md.

All three fixes are mirrored into this tree's `rust-keybindings.el` and
new `dape-config.el` (`load!`'d, `COPY`'d — same checklist as always).
**Bug 3's finding is aarch64-only, unverified here** — this x86_64 build
has not been run, so neither the lldb hang nor gdb's success against it
have been independently confirmed on this port. The fix is applied
preemptively on the assumption a hang this deep (survives `--privileged`)
is more likely an lldb-server issue in general than an aarch64-specific
one, but that assumption is exactly that. See DECISIONLOG.md's caveat on
the corresponding entry. If lldb turns out to work fine here, this tree
should keep it available even if aarch64 stays gdb-only.

#### Same day, second follow-up: bug 3 wasn't a host/arch problem — two ordinary, fixable bugs, both resolved on aarch64

Bug 3 above turned out to be a misdiagnosis. On the aarch64 tree: `strace`
(now a permanent apt package there, and mirrored here too) traced the
hang to `DEBUGINFOD_URLS` — Ubuntu's `/etc/profile.d/debuginfod.sh` sets
it for every login shell, lldb has no interactive gate for it the way
gdb does, and just hangs reaching `debuginfod.ubuntu.com`. Fixing that
wasn't sufficient on its own, though — testing against the actual,
unmodified `run.sh` (zero extra capabilities) surfaced the *original*
`personality set failed` error again, since the earlier `--privileged`
testing had been bypassing that problem the whole time rather than
solving it. The real fix for that turned out to need no container
privilege change at all: `lldb-dap` has its own dedicated DAP launch
argument, `:disableASLR`, that skips the ASLR-disable syscall entirely
when set false — found after two dead ends (`~/.lldbinit` and an
`initCommands` launch argument both run too late to matter).

Net result on aarch64: lldb debugging works correctly in the actual
default container configuration, fixed by one Dockerfile `ENV` line
(`DEBUGINFOD_URLS=""`) and one dape config key (`:disableASLR nil`) — no
`run.sh` changes, no capability/seccomp loosening. This morning's gdb-flip
is fully reverted; lldb is back as Rust's debugger and a free alternative
for C/C++, exactly as originally decided. Full account, including why the
privilege-level testing wasn't wasted work, is in DECISIONLOG.md.

All of this is mirrored here (Dockerfile, `dape-config.el`,
`rust-keybindings.el`, flight-test doc, DECISIONLOG.md) but **still not
independently verified on this x86_64 tree** — same caveat as bug 3's
original entry, just resolved in the opposite direction. Both fixes are
generic enough (an env var; a standard lldb-dap DAP argument) that they
should hold here too, but that's an expectation, not a confirmed result.

#### C/gdb debugging validated live — and a real, IDE-wide gap found along the way

Found and fixed entirely on the aarch64 tree; see that tree's BUILDLOG.md
entry of the same title for the full account. Short version: circling
back to confirm the one thing the original C/CMake entry (and its
debugger follow-up) had explicitly flagged as unverified — an actual live
gdb debug session — a breakpoint got silently ignored, same outward
symptom as the lldb-dap race condition elsewhere in this log but a
different, much more mundane cause: the flight-test's `CMakeLists.txt`
sets no `CMAKE_BUILD_TYPE`, so the compiled binary had zero DWARF debug
info (`objdump --dwarf=info` came back empty) — nothing for gdb to break
on, correctly wired or not.

The bigger finding: this project's own `+cmake/configure` binding
(`SPC m b c`) ran the identical bare `cmake -B build -S .` with no
build-type flag, meaning every C/C++ project configured through the
IDE's own recommended default workflow would hit the same silent
"breakpoints never work" wall. Fixed by adding
`-DCMAKE_BUILD_TYPE=Debug` to `+cmake/configure` itself. Verified live on
aarch64: rebuilt, confirmed debug info present, set a fresh breakpoint,
correct stop with populated locals. `cmake-keybindings.el`'s code change
is mirrored here; this specific validation (the live gdb session, the
debug-info check) has not been independently repeated on x86_64.

#### Field notes from actually driving the C debugger, same session

Mirrored from the aarch64 tree's entry of the same title — three smaller,
non-bug findings from using the now-working debugger for real, worth
having on record here too since none of them are aarch64-specific:

- `SPC d d` pre-fills from `dape-history`'s most recent entry that's
  still valid for the current buffer's mode, not "the right debugger for
  this language" — a Rust session's `lldb-dap` choice is a legitimate,
  silently pre-filled suggestion in a `c-mode` buffer too, since
  `lldb-dap`'s `modes` list deliberately still includes `c-mode`/
  `c++-mode`. Read the prompt before accepting it.
- Live variable editing (`=` in the Scope buffer, `dape-info-variable-edit`)
  works as expected — confirmed against a paused C session, editing a
  struct field mid-pause and continuing to see the edited value actually
  used.
- A paused program's `printf` output can be invisible without being
  lost — stdout auto-switches to fully-buffered the moment it's not a
  real terminal, which DAP-captured output always is. Not a bug; shows up
  on exit, or on demand via `` call fflush(stdout)`` sent directly to the
  REPL.

---

#### Go/dlv debugging validated live -- same class of root-detection bug as CMake's, one layer further down

Circled back to validate the one debugger integration from this whole
systems-ide effort that had never actually been driven end-to-end: Go's
`dlv` config, working since the original Go bring-up by every account in
this log, but never live-tested against a project nested inside a larger
git repo the way flight-tests/go/ is.

`SPC d d` against `flight-tests/go/flight-test.go` errored immediately:

```
Building .Build Error: go build -o /home/josiah/Development/personal/automation-engineering/docker-emacs/__debug_bin1939784951 -gcflags all=-N -l .
go: cannot find main module, but found .git/config in /home/josiah/Development/personal/automation-engineering/docker-emacs
	to create a module there, run:
	go mod init (exit status 1)
```

`go build` ran from the docker-emacs repo root, not from flight-tests/go/
where the actual `go.mod` lives. dape's built-in `dlv` config launches
delve with `:program "."`/`:cwd "."` -- both resolved by delve itself
relative to the *adapter process's own* working directory
(`command-cwd`, defaulting to `dape-command-cwd` -> `project-current`).
Traced live via `emacsclient -e`: `project-current` was returning the
docker-emacs repo root, not flight-tests/go/, even after confirming
`go.mod` sits right there and even after adding `"go.mod"` to
`project-vc-extra-root-markers` and clearing project.el's own root
cache by hand -- the marker made no difference at all. Root cause one
layer further down than expected: Doom prepends `project-projectile`
ahead of project.el's own VC backend in `project-find-functions`
(confirmed via `(default-value 'project-find-functions)` against the
live daemon), so it's Projectile's root-finding that actually wins, and
`projectile-project-root-files-bottom-up` -- the marker list that
correctly handles a project nested inside a bigger VCS tree -- has no
`go.mod` entry at all (nor `CMakeLists.txt`, for what it's worth; C/CMake
just never hit this because `+dape-cmake-program` already bypasses
`project-current` entirely for its own `:program` resolution).

Exact same class of bug as `+cmake--root`'s near-miss from the original
C/CMake bring-up -- project-root machinery assuming a VCS boundary is
the real project boundary -- just surfacing here because Go's dlv config
is the one debugger integration in this file that never got its own
`locate-dominating-file`-based bypass the way cargo and CMake did.

**Fix:** `dape-config.el` gains `+dape-go-root`, walking up for `go.mod`
directly (same shape as `+dape-cargo-program`/`+dape-cmake-program`),
and overrides the `dlv` config's `command-cwd` to use it instead of
dape's default `project-current`-based guess. No change to
`project-vc-extra-root-markers` or Projectile's own root-file lists --
narrower blast radius, and consistent with how the other two debuggers
already sidestep project-root detection rather than trying to fix it
globally.

**Verified live, twice** (once patching `dape-configs` ad hoc via
`emacsclient -e` to confirm the fix shape works at all, once more after
writing the real fix to `dape-config.el` and `load-file`ing it fresh into
the running daemon to confirm the actual on-disk file is what's tested,
not a hand-patched approximation of it): `SPC d d` now builds from
flight-tests/go/ correctly, breakpoint on `fmt.Println(message)` stops
there with `message "Hello"` populated in the Scope buffer. Only verified
on aarch64 so far; x86_64 mirrors the same fix but hasn't been
independently confirmed against its own rebuilt image.

**Not yet done:** this fix lives in the source tree only -- the running
container this was tested against had `dape-config.el` reloaded live via
`load-file` for verification, but its baked-in image still predates this
change. A rebuild is needed before `SPC d d` picks this up by default in
a fresh container.

---

#### Follow-up, same session: the Go fix wasn't the whole story -- gdb/lldb-dap/lldb-vscode had the identical bug

Right after the Go/dlv fix above landed, a second look at Rust's own
flight-test (previously confirmed working earlier this same session) now
failed too, complaining about being unable to find its `Cargo.toml` --
and C's gdb session, tested separately, showed the exact "No source file
named .../main.c ... Breakpoint 1 ... pending" symptom from way back at
the start of tonight's debugging (originally assumed, at the time, to be
purely the missing-debug-symbols bug -- it wasn't only that).

**Root cause, one layer deeper than the Go fix reached:** dape's
`dape--guess-root` -- called to bind `default-directory` *before*
`:program` gets evaluated for any config -- reads a config's own
`command-cwd` first, falling back to `dape-command-cwd` only if unset.
`gdb`/`lldb-dap`/`lldb-vscode`'s built-in configs all default `command-cwd`
to `dape-command-cwd` too, exactly like `dlv` did. Fixing only `dlv`'s
`command-cwd` left the other three routing through the same broken
`project-current` chain -- but where Go's `dlv` has no `:program`
resolver of its own and fails loudly ("cannot find main module"), gdb/
lldb-dap's `+dape-cargo-program`/`+dape-cmake-program` resolvers just
silently found no root either (their own internal
`locate-dominating-file` calls, poisoned by the same wrong
`default-directory`) and fell through to dape's literal `"a.out"`
default -- a much quieter failure that read, at first glance, like a
missing binary rather than a resolution bug.

**Fix:** `dape-config.el` gains `+dape-resolve-cwd` (tries `Cargo.toml`,
then `CMakeLists.txt`, same shape as `+dape-resolve-program`), applied as
`command-cwd` for `gdb`/`lldb-dap`/`lldb-vscode` alongside the existing
`:program` override. `+dape-go-root` stays as `dlv`'s own separate
`command-cwd`, since Go's marker file is different and it has no
`:program` resolver to share logic with.

**Verified live, all three languages, in the docker-emacs repo's own
nested flight-test copies** (not the `~/flight-tests/` image-baked
copies, which never hit this since they're not nested inside a larger
git tree):
- Go: `dlv` build succeeds from `flight-tests/go/`, breakpoint stops with
  `message` populated (already covered above).
- Rust: `lldb-dap` launches `flight-tests/rust/target/debug/flight-test`
  correctly, `:stopOnEntry` pause then `dape-continue` reaches
  `flight_test::main` / `src/main.rs:17` with `message`/`c` populated.
- C: `gdb` resolves `flight-tests/c/build/ctest` correctly, breakpoint on
  `print_greeting(&g);` stops with `unused 42`/`g` populated. (The
  "Breakpoint 1 ... pending" message still prints during the request
  race -- gdb warns and self-heals once the binary loads, same
  warn-and-proceed character as its ASLR/`personality()` behavior
  documented in DECISIONLOG.md -- but the breakpoint now resolves
  correctly instead of staying pending forever with no binary to attach
  to.) Confirmed independently by re-testing both gdb and lldb-dap
  against the C fixture after this fix.

Only verified on aarch64 so far; x86_64 mirrors the same fix but hasn't
been independently confirmed against its own rebuilt image. Same
not-yet-rebuilt caveat as the entry above -- this was verified via
`load-file` into the running daemon, not a fresh container boot.

---

#### Python gets a real debugger

`python3-debugpy` added via apt (not pip -- keeps this tier's "no pip/
poetry/conda" rule intact; it's an `Architecture: all` package in
Ubuntu's universe repo, no per-arch build needed). dape already has a
built-in `debugpy`/`debugpy-module` config, so no new dape-config.el
entry was needed the way Lua required one. One real gap found and fixed:
this image ships only a versioned `python3`, no bare `python`, and
dape's built-in config hardcodes `command "python"` -- same shape of gap
`lua5.4`/`lua` needed fixing for Lua, fixed the same way (a symlink under
`~/.local/bin`).

Ruby deliberately does not get an equivalent -- see DECISIONLOG.md for
the full reasoning (pry through the existing `inf-ruby` REPL integration
already covers that need there, and Python's glue scripts have shown
more real debugging need in practice than Ruby's have).

Verified live: breakpoint inside `main()` in `flight-tests/python/
deploy.py`, correct stop, clean continue through `import tasks` to exit.
`debugpy` itself couldn't be installed via apt in the already-running
container (no network access at runtime, by design -- confirmed the hard
way when a live `apt-get update` attempt hung on DNS resolution, same
failure mode as the earlier lldb-dap DEBUGINFOD_URLS hang). Verified
instead by vendoring the actual `.deb`'s Python package files in from a
disposable `docker run ubuntu:26.04` container (which does have build-
time network access) directly into the running container's
`dist-packages`, purely for this test -- the real install path (baked in
at image build time, via apt) is untouched and unaffected by this.

Only verified on aarch64 so far; x86_64 mirrors the same fix but hasn't
been independently confirmed against its own rebuilt image.
