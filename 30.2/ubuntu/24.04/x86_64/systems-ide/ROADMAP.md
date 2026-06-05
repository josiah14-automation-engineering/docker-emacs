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

## Step 2: Go — [#2](https://github.com/josiah14-automation-engineering/docker-emacs/issues/2)

Prioritized above the systems languages — the FaradAI CLI rewrite (#65) targets
Go. Full LSP + toolchain needed before that migration work starts.

**Dockerfile:**
- Add a `go-build` stage to download and verify the toolchain:
  ```dockerfile
  FROM ubuntu:24.04 AS go-build
  ARG GO_VERSION=<pin>
  ARG GO_SHA256=<pin>
  RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates curl \
      && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz \
      && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c - \
      && tar -C /usr/local -xzf /tmp/go.tar.gz \
      && rm /tmp/go.tar.gz
  ```
- In the final stage, copy the toolchain and set up PATH:
  ```dockerfile
  COPY --from=go-build /usr/local/go /usr/local/go
  ENV GOPATH=/home/${USERNAME}/go
  ENV PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"
  ```
- After the `USER ${USERNAME}` switch, install gopls:
  ```dockerfile
  RUN go install golang.org/x/tools/gopls@v<pin>
  ```
- `COPY go-keybindings.el`

**init.el:**
- Add `(go +lsp)` to `:lang` ✓ (already done)

**config.el:**
- Add `(load! "go-keybindings")`

**Note:** Go version management uses the native Go 1.21+ `toolchain` directive.
See DECISIONLOG.md. Future goenv support tracked in [#20](https://github.com/josiah14-automation-engineering/docker-emacs/issues/20).

**Verify:**
- Open a `.go` file; confirm gopls completions, go-to-definition, and flycheck errors
- Confirm `gofmt` runs on save (Doom's go module enables this with `+lsp`)
- Run `go version` and `gopls version` inside the container

---

## Step 3: Nushell — [#3](https://github.com/josiah14-automation-engineering/docker-emacs/issues/3)

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

## Step 4: C — [#4](https://github.com/josiah14-automation-engineering/docker-emacs/issues/4)

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

## Step 5: C++ — [#5](https://github.com/josiah14-automation-engineering/docker-emacs/issues/5)

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

## Step 6: Rust — [#6](https://github.com/josiah14-automation-engineering/docker-emacs/issues/6)

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

## Step 7: Zig — [#7](https://github.com/josiah14-automation-engineering/docker-emacs/issues/7)

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

## Step 8: CMake — [#8](https://github.com/josiah14-automation-engineering/docker-emacs/issues/8)

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

## Step 9: Lua — [#9](https://github.com/josiah14-automation-engineering/docker-emacs/issues/9)

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

## Step 10: Nix — [#10](https://github.com/josiah14-automation-engineering/docker-emacs/issues/10)

Installs only the `nil` LSP binary — not the Nix daemon. Static analysis of
Nix expressions works without a running Nix installation.

**Dockerfile:**
- Download `nil` binary from GitHub releases:
  https://github.com/oxalica/nil/releases
  Pin version and sha512; install to `/usr/local/bin`

**init.el:**
- Add `nix` to `:lang`

**config.el:**
- Add `(load! "nix-keybindings")`

**Verify:** Open a `.nix` file; confirm nil provides completions and go-to-definition
within the file. Note: cross-file resolution requires a Nix flake/nixpkgs context
mounted from the host.

---

## Step 11: Guile / Scheme — [#11](https://github.com/josiah14-automation-engineering/docker-emacs/issues/11)

Uses Geiser (REPL integration) rather than LSP — the correct Emacs-idiomatic
approach for interactive Lisp development.

**Dockerfile:**
- Add `guile-3.0` to the apt list

**init.el:**
- Add `(scheme +guile)` to `:lang`

**packages.el:**
- Add `(package! geiser-guile)` to pin the Guile backend explicitly

**config.el:**
- Add `(load! "guile-keybindings")`

**Verify:** Open a `.scm` file; confirm Geiser activates. Run `M-x geiser-guile`
to start a Guile REPL and send a form with `C-c C-e`.

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
