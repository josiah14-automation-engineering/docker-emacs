# Go IDE Flight Test

Covers every keybinding in `go-keybindings.el`. Run top to bottom on a fresh container boot.

## Setup

```bash
./run.sh -f go
```

Open `~/flight-tests/go/flight-test.go`. Wait for the mode line to show `LSP[gopls]`
before proceeding.

---

## LSP Basics

- [x] **`K`** — position on `fmt.Println` in `main`. Expect a hover popup with the
  function signature and godoc.

- [x] **`g d`** — position on a call to one of the local functions (e.g. `NewCounter`).
  Expect jump to its definition in the same file.

- [x] **`g D`** — position on `Counter` (the type name). Expect an xref buffer listing
  all references.

- [x] **`SPC c r`** — position on a local symbol (e.g. a variable in `main`). Invoke,
  type a new name, confirm. Verify all occurrences renamed. Undo afterward.

- [x] **`SPC c a`** — position on a line with an available code action (e.g. an
  unhandled error return, or a missing struct field). Expect a code-action menu.

- [x] **`] d`** / **`[ d`** — introduce a deliberate error (e.g. `var _ int = "oops"`),
  save, then cycle through diagnostics. Remove the error when done.

- [x] **`SPC b c`** — flycheck the buffer. Expect no errors on a clean file.

---

## Imports

- [x] **`SPC m i`** — jump point to the `import` block.

- [x] **`SPC m h .`** — position on a stdlib identifier (e.g. `Println`). Expect a
  godoc buffer for the symbol.

- [x] **`SPC m I`** — invoke, type `strings`, confirm. Verify the import is added. Undo.

---

## Struct Tags

Requires a struct with exported fields in `flight-test.go`.

- [x] **`SPC m a`** — position on an exported struct field. Add a `json` tag. Verify the
  tag appears inline.

- [x] **`SPC m d`** — position on the same field. Remove the tag. Verify it's gone.

---

## Build

- [x] **`SPC m b b`** — `go build`. Expect a `*compilation*` buffer with exit 0.

- [x] **`SPC m b r`** — `go run .`. Expect program output in a `*compilation*` buffer.

- [x] **`SPC m b c`** — `go clean`. Expect exit 0, no output.

---

## Generate

Requires a `//go:generate` directive in `flight-test.go`.

- [x] **`SPC m g f`** — generate for current file. Expect the `go generate` command to
  run in a `*compilation*` buffer.

- [x] **`SPC m g d`** — generate for current directory.
fl

- [x] **`SPC m g a`** — generate for `./...`.

---

## Lint

- [x] **`SPC m l`** — lint current package. Expect `golangci-lint run .` in
  `*compilation*`, exit 0 on a clean file.

- [x] **`SPC m L`** — lint all (`./...`). Same expectation.

---

## Tests

Requires `flight-test_test.go` with table-driven tests and benchmarks.

- [x] **`SPC m t f`** — test current file. Expect `go test` output, all pass.

- [x] **`SPC m t a`** — `go test ./...`. All pass.

- [x] **`SPC m t s`** — position inside a `TestXxx` function body. Runs that test only.

- [x] **`SPC m t n`** — position inside a subtest `t.Run(...)` call. Runs the parent test
  filtered to that subtest.

- [x] **`SPC m t t`** — rerun the last test without moving point.

- [x] **`SPC m t g`** — position on `Untested` (an exported function with no test).
  Expect a stub `TestUntested` generated into a `_test.go` buffer.

- [x] **`SPC m t G`** — generate stubs for all exported symbols that lack tests.

- [x] **`SPC m t e`** — generate stubs for exported symbols only (subset of `G`).

---

## Benchmarks

- [x] **`SPC m p s`** — position inside a `BenchmarkXxx` function. Runs that benchmark.

- [x] **`SPC m p a`** — run all benchmarks.

---

## REPL

- [x] **`SPC m r r`** — cold start. Expect a `gore` REPL buffer without error.

- [x] **`SPC m r R`** — load current file into the REPL. Expect the package loaded; call
  a function from the file to verify (`main()` or any exported function).

- [x] **`SPC m r e`** — position on an expression line in the REPL buffer. Eval it.

- [x] **`SPC m r n`** — eval a line and advance point to the next.

- [x] **`SPC m r E`** — select a region spanning two expressions. Eval the region.

---

## Playground

- [x] **`SPC m e`** — with the buffer or a region selected, send to `play.golang.org`.
  Expect a browser tab (or URL in the minibuffer) with the snippet.

---

## Rename / Refactor (global)

Already covered above under LSP Basics (`SPC c r`). Listed here for completeness.

---

## Checklist summary

| Group       | Bindings                                                  |
|-------------|-----------------------------------------------------------|
| LSP         | `K`, `g d`, `g D`, `SPC c r`, `SPC c a`, `] d`, `[ d`, `SPC b c` |
| Imports     | `SPC m i`, `SPC m h .`, `SPC m I`                         |
| Struct tags | `SPC m a`, `SPC m d`                                      |
| Build       | `SPC m b r`, `SPC m b b`, `SPC m b c`                     |
| Generate    | `SPC m g f`, `SPC m g d`, `SPC m g a`                     |
| Lint        | `SPC m l`, `SPC m L`                                      |
| Tests       | `SPC m t f/a/s/n/t/g/G/e`                                 |
| Benchmarks  | `SPC m p s`, `SPC m p a`                                  |
| REPL        | `SPC m r r/R/e/n/E`                                       |
| Playground  | `SPC m e`                                                 |
