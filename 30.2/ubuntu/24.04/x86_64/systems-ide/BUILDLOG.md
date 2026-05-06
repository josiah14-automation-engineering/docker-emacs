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
