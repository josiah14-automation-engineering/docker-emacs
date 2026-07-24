# Zig IDE Flight Test

Covers every keybinding relevant to zig-mode (Doom's own `:lang zig` module
bindings -- no `zig-keybindings.el` exists, unlike Rust/Go: the module already
wires `b`/`f`/`r`/`t` itself via `+zig-common-config`, so there's nothing left
to add). Run top to bottom on a fresh container boot.

## Setup

```bash
./run.sh -f zig
```

Open `~/flight-tests/zig/src/main.zig`. Wait for the mode line to show
`LSP[zls]` before proceeding.

---

## LSP Basics

- [x] **`K`** — position on `Counter` in `main.zig`. Expect a hover popup with
  the struct definition and its doc comment from `counter.zig`.
  Verified live: hover on `Counter` (not `counter`, the module alias --
  those are different symbols and only the type name resolves to the
  struct) returns the struct shape plus its doc comment.

- [x] **`g d`** — position on `Counter` or `c.inc()`. Expect a jump across
  files into `counter.zig`.
  Verified live: jumps to `counter.zig:5`, the actual `pub const Counter =
  struct {` line. (Note: positioning on `counter`, the module alias,
  instead jumps to `counter.zig:1` -- also correct, that's the module's
  own "definition", not a bug.)

- [x] **`g D`** — position on `Counter` (the type name). Expect an xref
  buffer listing all references, across both files.
  Verified live via the raw `textDocument/references` request: returns
  both the declaration in `counter.zig` and the usage in `main.zig`.

- [x] **`SPC c r`** — position on `c` (the local variable in `main`). Invoke,
  type a new name, confirm. Verify all occurrences renamed. Undo afterward.
  Verified live via the raw `textDocument/rename` request: correctly
  finds all 4 occurrences of `c` in `main.zig` (declaration, `c.inc()`,
  and both interpolations in the print call).

- [ ] **`SPC c a`** — position on a line with an available code action, if
  zls offers one for this file. **Not verified this pass** -- a raw
  `textDocument/codeAction` request with no `:context` (no diagnostics
  array) hung zls indefinitely, and since `lsp-request` is a synchronous
  blocking call, it froze the entire single-threaded Emacs session (even
  a bare `(+ 1 1)` eval timed out). This was almost certainly a malformed
  request on my part (references/rename both needed an explicit
  `:context`; code actions likely do too), not necessarily a real zls
  bug -- but confirm with a properly-formed request (or by just invoking
  `SPC c a` interactively, which builds the request correctly) before
  trusting this binding. A `kill -INT 1` inside the container did recover
  the *next* container relaunch but killed the hung one entirely (PID 1
  signal handling in a container is not the same as C-g in an interactive
  frame) -- if this hangs again, relaunch rather than waiting.

- [x] **`] d`** / **`[ d`** — uncomment the deliberate syntax error in
  `main.zig` (`const bad = 5` with no trailing semicolon), save, then cycle
  through diagnostics. Remove the error when done.
  Verified live via `lsp-diagnostics` directly: zls reports "expected ';'
  after statement" at the correct line/column.

- [x] **`SPC b c`** — flycheck the buffer. Expect no errors on a clean file.
  **Correction from the original note below:** confirmed live that
  `flycheck-get-checker-for-buffer` reports `lsp`, not `zig` -- Doom's
  manually-registered `zig` checker (`zig ast-check`) is present but
  shadowed by lsp-mode's own flycheck integration whenever `+lsp` is
  active, the same checker-priority-contest shape already documented for
  ruby-lsp-ls/rubocop-ls in this project. Since `lsp` wins, flycheck
  actually gets zls's *own* diagnostics, not the narrower ast-check ones
  -- confirmed live that both a genuine syntax error (missing semicolon)
  *and* a genuine semantic error (an unused local, which Zig's compiler
  treats as an error) both surface correctly through this path. The
  ast-check-only limitation described below never actually applies in
  practice in this image.
  <details><summary>Original note (superseded, kept for context)</summary>
  `zig ast-check` only validates AST/syntax, not semantics -- a genuine
  type error (e.g. `const x: i32 = "not an int";`) exits 0 under
  `ast-check` even though `zig build`/`zig build-exe` correctly reject
  it. This is still true of `ast-check` in isolation; it just turned out
  not to matter here since `lsp` is the checker that actually runs.
  </details>

---

## Debug (dape / lldb-dap)

- [x] **`SPC d d`** — with point in `main.zig`, invoke, select `lldb-dap`.
  Set a breakpoint on `c.inc();` first (`SPC d b`, or the dape default).
  Expect the debug session to build (`zig build`) and launch, stopping at
  the breakpoint. Inspect `c` in the dape info buffer -- expect to see
  `n: 0`. Step over (`n`), expect `n: 1`. Continue to completion.
  Verified live, end to end: `+dape-zig-program` correctly returns the
  buffer-basename fallback when `zig-out/bin/` doesn't exist yet (no
  build run), and correctly resolves to
  `~/flight-tests/zig/zig-out/bin/flight-test` after a real `zig build`
  -- `+dape-resolve-cwd` resolved `~/flight-tests/zig/` via the `build.zig`
  marker throughout. `:stopOnEntry` (shared lldb-dap config, see
  dape-config.el) stopped first inside Zig's own std-library startup code
  (`Target.Cpu.Arch.isRiscv32`, not literally line 1 of `main` -- Zig's
  runtime entry path differs from Rust's, same underlying mechanism);
  `SPC d c` continued to the real breakpoint at `main.zig:20`. Inspecting
  `c`'s `variablesReference` showed `n: "0"`; stepping over advanced to
  line 21 with `n: "1"`. Continuing to completion printed the full
  expected output (`Hello`, `Counter{ .n = 1, .name = "test" }`, `0`-`9`)
  and exited status 0.

---

## Build / Run / Test

- [x] **`SPC m b`** (`zig-compile`) — `zig build`. Expect a compilation
  buffer, exit 0. Verified live.

- [x] **`SPC m r`** (`zig-run`) — **Correction:** actually runs `zig run
  <buffer-file> -O Debug` directly, not `zig build run` -- confirmed live
  in the `*compilation*<zig>` buffer. Same per-file approach as
  `zig-test-buffer` below, not routed through `build.zig` at all. Program
  output (`Hello`, the `Counter` repr, `0`-`9`) appears correctly.

- [x] **`SPC m t`** (`zig-test-buffer`) — with point in `counter.zig`,
  invoke. Runs `zig test <buffer-file> -O Debug` directly (confirmed live),
  reports "All 1 tests passed."

---

## Format

- [ ] **`SPC m f`** (`zig-format-buffer`) — Doom's own module binding calls
  `zig-format-buffer` directly, not apheleia's `SPC m f` convention used
  elsewhere in this image -- introduce a formatting nit (extra blank line),
  invoke, verify it's cleaned up. **Not independently verified this pass**
  (format-on-save below was verified instead, which exercises the same
  underlying `zig fmt`); low-risk, same mechanism.

- [x] **Format-on-save** — apheleia's own built-in default formatter for
  zig-mode/zig-ts-mode is `zig-fmt` (`zig fmt --stdin`, confirmed directly in
  apheleia-formatters.el at this project's pinned commit) -- Doom's zig
  module explicitly sets `zig-format-on-save nil` to defer to this instead
  of double-formatting. Verified live: inserted two leading blank lines,
  saved, apheleia stripped them back out automatically with no `SPC m f`
  needed; file returned to its original, correctly-formatted 29 lines.

---

## Checklist summary

| Group        | Bindings                                    |
|--------------|----------------------------------------------|
| LSP          | `K`, `g d`, `g D`, `SPC c r`, `SPC c a`, `] d`, `[ d`, `SPC b c` |
| Debug        | `SPC d d`                                    |
| Build/Run/Test | `SPC m b`, `SPC m r`, `SPC m t`             |
| Format       | `SPC m f`, format-on-save                    |
