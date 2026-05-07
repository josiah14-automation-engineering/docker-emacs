# TODO

The systems-ide starts from a working bare Doom base (cross-language tooling
only) and adds language support one at a time. Each step below has a Dockerfile
change and a config change. Verify each addition builds and works before moving
to the next.

---

## Step 1: Shell (bash/sh/zsh/ksh) — configuration complete, build pending

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

## Step 2: C

**Dockerfile:**
- Add `gcc clangd gdb` to the apt list
- No new build stage needed

**init.el:**
- Add `(cc +lsp)` to `:lang`

**config.el:**
- Add `(load! "c-keybindings")` to activate the keybindings file
- Add C style preferences:
  ```elisp
  (setq c-default-style "linux"
        c-basic-offset 4)
  ```

**Verify:** Open a `.c` file; confirm clangd completions and flycheck errors.
Run `M-x dap-debug` with a gdb configuration to confirm debugging works.

---

## Step 3: C++

C++ is covered by the same `:lang (cc +lsp)` module as C. No Doom or Dockerfile
changes needed if Step 2 is complete. This step is about verifying and configuring:

**Dockerfile:**
- Add `g++ clang` to the apt list (clang++ comes with clang)

**config.el:**
- Confirm `c-default-style` applies to C++ buffers. Add a `c++-mode` hook if
  separate style settings are needed.

**Verify:** Open a `.cpp` file; confirm clangd works. Test with a `CMakeLists.txt`
project to confirm `compile_commands.json`-based navigation works across files.

---

## Step 4: Rust

Rust requires rustup, which installs to `~/.cargo` as the runtime user. This means
the install runs in the final image as the user, after the user switch.

**config.el:**
- Add `(load! "rust-keybindings")` to activate the keybindings file

**Dockerfile:**
- Add `ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"` after the user switch
- Add a `RUN` step as the user:
  ```dockerfile
  RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
           | sh -s -- -y --no-modify-path --default-toolchain stable \
      && ~/.cargo/bin/rustup component add rust-analyzer rust-src
  ```
- TODO: pin rustup installer sha256 before adding this step

**init.el:**
- Add `(rust +lsp)` to `:lang`

**Verify:** Open a `.rs` file; confirm rust-analyzer completions, go-to-definition
into std, and flycheck errors. Run `rustc --version` inside the container.

**Debugging (deferred):** Wire codelldb for Rust debugging. codelldb is a DAP
server distributed as a `.vsix` from GitHub releases. Steps:
1. Download and verify sha512 for the Linux x86_64 release
2. Extract `adapter/` directory to a stable path in the image
3. In config.el: `(setq dap-codelldb-extension-path "<path>")`
4. Add `(require 'dap-codelldb)` to config.el

---

## Step 5: Zig

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
- Add `(load! "zig-keybindings")` to activate the keybindings file

**Verify:** Open a `.zig` file; confirm zls completions. Run `zig version` and
`zls --version` inside the container.

---

## Step 6: CMake

Natural addition after C/C++. Lightweight — cmake-language-server is a pip package.

**Dockerfile:**
- Add `python3 python3-pip` to the apt list (if not already present)
- Add `RUN pip3 install --break-system-packages cmake-language-server`

**init.el:**
- Add `cmake` to `:lang`

**config.el:**
- Add `(load! "cmake-keybindings")` to activate the keybindings file

**Verify:** Open a `CMakeLists.txt`; confirm completions and hover docs.

---

## Step 7: Lua

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
- Add `(load! "lua-keybindings")` to activate the keybindings file

**Verify:** Open a `.lua` file; confirm completions. Run `lua5.4 --version`
and `lua-language-server --version` inside the container.

---

## Step 8: Nix

Installs only the `nil` LSP binary — not the Nix daemon. Static analysis of
Nix expressions works without a running Nix installation.

**Dockerfile:**
- Download `nil` binary from GitHub releases:
  https://github.com/oxalica/nil/releases
  Pin version and sha512; install to `/usr/local/bin`

**init.el:**
- Add `nix` to `:lang`

**config.el:**
- Add `(load! "nix-keybindings")` to activate the keybindings file

**Verify:** Open a `.nix` file; confirm nil provides completions and go-to-definition
within the file. Note: cross-file resolution requires a Nix flake/nixpkgs context
mounted from the host.

---

## Step 9: Guile / Scheme

Uses Geiser (REPL integration) rather than LSP — the correct Emacs-idiomatic
approach for interactive Lisp development.

**Dockerfile:**
- Add `guile-3.0` to the apt list

**init.el:**
- Add `(scheme +guile)` to `:lang`

**packages.el:**
- Add `(package! geiser-guile)` to pin the Guile backend explicitly

**config.el:**
- Add `(load! "guile-keybindings")` to activate the keybindings file

**Verify:** Open a `.scm` file; confirm Geiser activates. Run `M-x geiser-guile`
to start a Guile REPL and send a form with `C-c C-e`.

---

## Step 10: TOML

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

## Step 11: Assembly

Syntax only — no LSP, no debugger integration needed beyond what gdb already provides.

**init.el:**
- Add `asm` to `:lang`

**Verify:** Open a `.asm` or `.s` file; confirm syntax highlighting.

---

## Step 12: Syntax-only batch

All lightweight. Add to init.el in one go; no Dockerfile changes.

**Dockerfile:**
- Add `ruby perl fish` to the apt list (runtimes for running scripts, not just reading)

**init.el:**
- Add to `:lang`: `(python)`, `(go)`, `ruby`, `perl`

**packages.el:**
- Add `(package! fish-mode)` — Fish is not covered by `:lang sh`

**Verify:** Open one file of each type; confirm syntax highlighting fires.

---

## After all steps: hardening

Once all languages are working:

1. **Generate straight.el lockfile.** Walk `~/.config/emacs/.local/straight/repos/`
   and produce `straight-versions.el`, then `COPY` it into the Dockerfile before the
   final `doom sync`. Pins all 400+ packages to exact commits for reproducible builds.

2. **Pin rustup installer sha256.** Record the sha256 of `sh.rustup.rs` at build time
   and add a verification step before piping to sh.

3. **Wire codelldb for Rust/Zig debugging.** See Step 4 notes.

4. **Wire dap-gdb-lldb for C/C++ debugging.** Add `(require 'dap-gdb-lldb)` to
   config.el and document a sample launch configuration.

5. **Add GNOME launcher.** Mirror the mercury-ide `host/` pattern: a launch script
   and `.desktop` entry for one-click GUI launch from the application menu.
