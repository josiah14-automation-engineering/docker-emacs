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
