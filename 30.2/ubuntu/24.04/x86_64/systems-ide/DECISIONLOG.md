# Decision Log

---

## Drop godef; remap SPC m h . to LSP hover

**Date:** 2026-06-05
**Status:** Active

**Decision:** Do not install `godef`. Override Doom's `SPC m h .` (`godoc-at-point`)
with `lsp-describe-thing-at-point` in `go-keybindings.el`.

**Rationale:** `godef@latest` installs with `golang.org/x/tools` frozen at
`v0.0.0-20200226224502` (February 2020). That version predates Go 1.21's internal
reorganisation of `internal/goarch`, causing a nil-pointer panic at type-check time
on Go 1.26+. The project has had no release since 2020 and is effectively abandoned.
LSP hover via gopls is strictly superior — same information, no separate binary.

**Revisit if:** A maintained fork or successor to godef emerges with Go 1.21+ support.

---

## Go version management: native toolchain over goenv

**Date:** 2026-05-28
**Status:** Active
**Related issue:** [#20](https://github.com/josiah14-automation-engineering/docker-emacs/issues/20)

**Decision:** Use the native Go toolchain management mechanism (Go 1.21+) rather
than installing a version manager like goenv.

**How it works:** A single Go toolchain is baked into the image. When a project's
`go.mod` declares a `toolchain` directive (e.g. `toolchain go1.22.3`), Go
automatically downloads and runs that version on the fly. No extra tooling required.

**Rationale:** The simpler path. This container's purpose is reproducibility —
getting a consistent, fully-featured IDE environment — not security isolation.
The container does not need additional protection from outbound network access
beyond what the host already provides. Pulling Go toolchain versions at runtime
is no different from pulling any other project dependency, and the tradeoff
(simplicity vs. explicit version management) clearly favors simplicity here.

**Revisit if:**
- A project requires a Go version older than 1.21 (pre-toolchain-directive era)
- Offline-only builds become a hard requirement
- The auto-download behavior causes problems in practice (flaky builds, slow CI)

---

## Nix: SPC m l prefix for flake/REPL; SPC m r freed for LSP rename

**Date:** 2026-06-06
**Status:** Active

**Decision:** Reserve `SPC m l` as a Nix-tools prefix with four bindings:

| Key | Command | Action |
|-----|---------|--------|
| `SPC m l c` | `nix flake check` | Type-check and evaluate all outputs |
| `SPC m l u` | `nix flake update` | Update all flake inputs in `flake.lock` |
| `SPC m l d` | `nix develop` | Enter the default dev shell |
| `SPC m l r` | `nix-repl-show` | Open the Nix REPL |

`SPC m r` is left to LSP rename (the standard Doom refactor slot).

**Rationale:** The Doom nix module binds `SPC m r → nix-repl-show`, which collides with
nil's LSP rename binding on the same key. LSP rename wins in practice (last `map!` runs
after module setup). The REPL is not a tight edit-run loop — it's an exploratory tool
used occasionally — so it doesn't need a top-level slot. Moving it to `SPC m l r` groups
it with flake operations under a coherent "Nix evaluation" prefix.

`l` was chosen over a shift-key alternative (e.g. `SPC m L`) to avoid the shift key.
Flake commands — check, update, develop — are the operations most frequently needed in
a flake-driven project workflow and belong at a single-level prefix rather than buried
under `SPC m f` (format) or another occupied slot.

**Revisit if:** A dedicated Emacs nix-flake package emerges with its own binding conventions.

---

## Nix store bind mount: conditional detection, read-only/write split, MOUNT_HOST_NIX escape hatch

**Date:** 2026-06-16
**Status:** Active

**Decision:** Bind-mount the host's `/nix` store only when it exists (`[[ -d /nix ]]`), using a RO/RW split that keeps store contents immutable while allowing Nix's mutable bookkeeping. Provide `MOUNT_HOST_NIX=0` to opt out without touching the host's filesystem.

**Mount pattern:**

| Path | Mode | Reason |
|---|---|---|
| `/nix` | `:ro` | Store contents immutable; prevents container writes to the host store |
| `/nix/var/nix` | rw | Nix acquires `gc.lock` and writes `temproots` for any store operation; `:ro` here produces EBADF on lock acquisition |
| `/nix/var/nix/profiles` | `:ro` | `nix develop` writes to `gcroots/auto`, never to `profiles`; writable profiles = container can tamper with host profile generations |
| `~/.config/nix` | `:ro` | Config updates go through the host |
| `~/.local/state/nix` | `:ro` | Profile updates go through the host |

**Why conditional, not unconditional:** The `nix-source` COPY stage bakes a working `/nix` store into every image. When the host `/nix` is absent (or `MOUNT_HOST_NIX=0`), the container runs self-contained on that store — useful during host Nix outages, mid-upgrade states, or when evaluating a new IDE image before the host is wired up.

**Why `MOUNT_HOST_NIX` in addition to `[[ -d /nix ]]`:** The directory guard is insufficient for a corrupt or mid-upgrade host store — `/nix` exists as a directory in both cases. The env var provides an explicit opt-out that doesn't require filesystem surgery on the host.

**Revisit if:** A per-container Nix daemon eliminates the need for host-store sharing.


---

## Rust debugging: lldb over gdb

**Date:** 2026-07-19
**Status:** Active

**Decision:** Use lldb (via dape's `lldb-dap` config) as the debugger for
Rust, not gdb. Install the plain `lldb` apt package; no elisp config
needed.

**Rationale:**
- dape's own built-in configs already treat Rust as an lldb language:
  its `gdb` config's `modes` list is `(c-mode c++-mode hare-mode ...)` —
  rust-mode is absent — while `lldb-dap`/`lldb-vscode`'s `modes` list is
  `(c-mode c++-mode rust-mode rust-ts-mode rustic-mode ...)`. Using lldb
  means zero elisp customization; using gdb would require extending its
  `modes` list ourselves.
- Both debuggers are officially, equally supported by the Rust project
  itself (`rust-lang/rust/src/etc` ships parallel `gdb_providers.py` and
  `lldb_providers.py` pretty-printers, plus `rust-gdb`/`rust-lldb`
  wrapper scripts) — this was a real gap in lldb's favor of gdb for
  years, but it's closed now, so it wasn't the deciding factor.
- lldb is the ecosystem default elsewhere (VS Code's dominant Rust
  debugger extension, CodeLLDB, is lldb-based).
- dape's `gdb` config hard-requires gdb ≥ 14.1 (version-checked via
  regex on `gdb --version`); its lldb configs have no such gate. Not
  currently a blocker (Ubuntu 26.04 ships gdb 17.1 and lldb 21.1.6, both
  confirmed live), but one less thing to break on a future OS bump.

**Not a factor:** gdb's well-known macOS/SIP friction (code-signing
required to attach to processes) — doesn't apply inside this Linux
aarch64 container, only noted as context for debugging Rust on bare
macOS outside it.

**Side effect:** installing `lldb` for Rust also registers dape's
`lldb-dap`/`lldb-vscode` configs for c-mode/c++-mode (already in that
`modes` list too), alongside the existing `gdb` config — both become
selectable from `SPC d d`'s menu with no extra work. See the
"C debugging: keep gdb as primary" entry below for whether to act on that.

**Revisit if:** dape adds rust-mode to its default `gdb` config, or lldb
develops its own Rust-specific gap that gdb doesn't have.

---

## C debugging: keep gdb as primary, lldb available as a free alternative

**Date:** 2026-07-19
**Status:** Active

**Decision:** Do not change C/C++'s debugger from gdb to lldb. Both are
now installed and both are valid dape configs for c-mode/c++-mode (gdb
was already wired; lldb came along for Rust, see above) — leave gdb as
the tested, documented default and let lldb sit as a selectable
alternative in `SPC d d`'s menu for whoever wants it, rather than
switching or removing either.

**Rationale:** This is a "should we tear out something that already
works" question, not a "which do we set up" question (that was Rust's
situation, which had no working debugger at all beforehand). gdb for
c-mode/c++-mode is already installed, already dape-configured, and
already covered by an existing smoketest.bats assertion. There's no
concrete problem with it prompting a switch — the lldb-vs-gdb tradeoffs
researched for Rust (pretty-printer parity, ecosystem defaults, version
gates) are close to a wash for C/C++ specifically, where gdb is the far
more established default. Changing the tested/documented primary without
a specific gdb-for-C shortcoming would be churn, not improvement.

**Revisit if:** A concrete gdb-for-C/C++ problem surfaces (a bug,
missing feature, or version-gate breakage) that lldb doesn't share.


