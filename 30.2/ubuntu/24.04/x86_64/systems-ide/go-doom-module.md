# Go Doom Module — Reference

Doom ships `:lang (go +lsp)` — a complete, maintained module. No custom module needs
to be written. This file documents what the module provides and what remains to be
done for systems-ide integration.

---

## What `(go +lsp)` provides out of the box

### Packages installed

| Package | Purpose |
|---|---|
| `go-mode` | Major mode; syntax highlighting, indentation, import management |
| `gorepl-mode` | Interactive REPL via `M-x gorepl-run` |
| `go-tag` | Struct tag management |
| `go-gen-test` | Test stub generation |
| `flycheck-golangci-lint` | golangci-lint flycheck checker (conditional — see below) |

### LSP

gopls is auto-started on `go-mode-local-vars-hook` when `+lsp` is active. No manual
`lsp-register-client` needed — gopls is a first-class lsp-mode client.

### Format on save

Handled by Doom's `:editor format` module via `lsp-format-buffer` (gopls formats
natively). No explicit `gofmt-command` setting needed.

### Local-leader keybindings (all under `SPC m`)

These are wired by the module's `+go-common-config` helper and apply to both
`go-mode` and `go-ts-mode`:

| Chord | Function | Notes |
|---|---|---|
| `SPC m e` | `+go/play-buffer-or-region` | Send to play.golang.org |
| `SPC m i` | `go-goto-imports` | Jump to import block |
| `SPC m a` | `go-tag-add` | Add struct tag |
| `SPC m d` | `go-tag-remove` | Remove struct tag |
| `SPC m h .` | `godoc-at-point` | Lookup in godoc |
| `SPC m r i a` | `go-import-add` | Add an import |
| `SPC m b r` | `go run .` | Run package |
| `SPC m b b` | `go build` | Build package |
| `SPC m b c` | `go clean` | Clean build artifacts |
| `SPC m g f` | `+go/generate-file` | `go generate` current file |
| `SPC m g d` | `+go/generate-dir` | `go generate` current dir |
| `SPC m g a` | `+go/generate-all` | `go generate ./...` |
| `SPC m t t` | `+go/test-rerun` | Rerun last test |
| `SPC m t a` | `+go/test-all` | `go test ./...` |
| `SPC m t s` | `+go/test-single` | Test at point |
| `SPC m t n` | `+go/test-nested` | Test + subtests at point |
| `SPC m t f` | `+go/test-file` | Test current file |
| `SPC m t g` | `go-gen-test-dwim` | Generate test for symbol at point |
| `SPC m t G` | `go-gen-test-all` | Generate tests for all exported symbols |
| `SPC m t e` | `go-gen-test-exported` | Generate tests for exported symbols |
| `SPC m t b s` | `+go/bench-single` | Bench at point |
| `SPC m t b a` | `+go/bench-all` | Bench all |

### Standard LSP bindings (from `:tools lsp`, not specific to Go)

| Chord | Function |
|---|---|
| `g d` | Go to definition |
| `g D` | Find references |
| `K` | Hover documentation |
| `] d` / `[ d` | Next / prev diagnostic |
| `SPC c a` | Code actions |
| `SPC c r` | Rename symbol (lsp-rename) |

---

## What systems-ide still needs

### Dockerfile (AI authors)

- `go-build` stage: download Go 1.26.3, verify SHA256, extract to `/usr/local/go`
- Final stage: `COPY --from=go-build /usr/local/go /usr/local/go`
- `ENV GOPATH=/home/${USERNAME}/go`
- `ENV PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"`
- After `USER` switch: `RUN go install golang.org/x/tools/gopls@v0.22.0`
- `COPY go-keybindings.el` added to the COPY block

### `config.el` (Josiah authors)

One line: `(load! "go-keybindings")`

### `go-keybindings.el` (Josiah authors)

Given how complete the module's bindings are, this will be sparse. The main candidate
is `SPC m r r` → `lsp-rename` if a local-map alias is wanted (the global `SPC c r`
already covers it). Josiah decides what, if anything, to add.

---

## Open decision: golangci-lint

The module conditionally installs `flycheck-golangci-lint` when `:checkers syntax
-flymake` is active. The `golangci-lint` binary is not in the systems-ide image.

- **Skip for now:** gopls's built-in staticcheck covers most of the same ground.
  golangci-lint is a large install and can be added in a later hardening pass.
- **Include:** add `golangci-lint` to the Dockerfile (binary download from
  https://github.com/golangci/golangci-lint/releases — pin version + sha256).

Status: deferred. Default is skip; revisit after the Go step is verified working.

---

## Version pins

| Tool | Version | Hash |
|---|---|---|
| Go toolchain | 1.26.3 | SHA256 `2b2cfc7148493da5e73981bffbf3353af381d5f93e789c82c79aff64962eb556` |
| gopls | v0.22.0 | installed via `go install`; integrity via module proxy |
| Delve (dlv) | v1.26.3 | installed via `go install`; integrity via module proxy |
