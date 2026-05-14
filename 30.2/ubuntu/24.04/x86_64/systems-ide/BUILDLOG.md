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
