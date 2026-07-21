# Rust IDE Flight Test

Covers every keybinding relevant to rustic-mode (Doom's own `:lang rust` module
bindings, plus `rust-keybindings.el`'s addition). Run top to bottom on a fresh
container boot.

## Setup

```bash
./run.sh -f rust
```

Open `~/flight-tests/rust/src/main.rs`. Wait for the mode line to show
`LSP[rust-analyzer]` before proceeding.

---

## LSP Basics

- [x] **`K`** — position on `Counter` in `main.rs`. Expect a hover popup with
  the struct definition and its doc comment from `counter.rs`.

- [x] **`g d`** — position on `Counter` or `c.inc()`. Expect a jump across
  files into `counter.rs`.

- [x] **`g D`** — position on `Counter` (the type name). Expect an xref
  buffer listing all references, across both files.

- [x] **`SPC c r`** — position on `c` (the local variable in `main`). Invoke,
  type a new name, confirm. Verify all occurrences renamed. Undo afterward.

- [x] **`SPC c a`** — position on a line with an available code action (e.g.
  after adding an unused `let` binding). Expect a code-action menu.

- [x] **`] d`** / **`[ d`** — uncomment the deliberate error in `main.rs`
  (`let _: i32 = "not an int";`), save, then cycle through diagnostics.
  Remove the error when done.

- [x] **`SPC b c`** — flycheck the buffer. Expect no errors on a clean file.

---

## Debug (dape / lldb-dap)

- [x] **`SPC d d`** — with point in `main.rs`, invoke, select `lldb-dap`.
  Set a breakpoint on `c.inc();` first (`SPC d b`, or the dape default).
  Expect the debug session to build and launch, stopping at the breakpoint.
  Inspect `c` in the dape info buffer — expect to see `n: 0`. Step over
  (`n`), expect `n: 1`. Continue to completion.
  Verified live: launch, breakpoint hit at the correct line/frame
  (`flight_test::main` at `src/main.rs:17`), and a full accurate backtrace
  down through Rust's runtime internals to `_start`, all confirmed working
  end-to-end once `DEBUGINFOD_URLS` was cleared at the image level (see
  DECISIONLOG.md).

---

## Build

- [x] **`SPC m b b`** — `cargo build`. Expect a compilation buffer, exit 0.

- [x] **`SPC m b r`** — `cargo run`. Expect program output (`Hello`, the
  `Counter` debug repr, `0`–`9`) in a compilation buffer.

- [x] **`SPC m b c`** — `cargo check`. Faster than build, same exit-0
  expectation on a clean file.

---

## Format / Lint / Doc

- [x] **`SPC m f`** — format buffer (apheleia, rustfmt). Introduce a
  formatting nit (extra blank line), save or invoke directly, verify it's
  cleaned up.

- [x] **`SPC m b f`** — `cargo fmt`, Doom's own module binding for the same
  underlying tool via a different path. Confirm it behaves the same as
  `SPC m f`.

- [x] **`SPC m b C`** — `cargo clippy`. Expect a compilation buffer; clean
  file should report no lints (this flight-test's code doesn't intentionally
  trip any clippy lints).

- [x] **`SPC m b d`** — `cargo doc`. Expect a compilation buffer, exit 0,
  builds HTML docs into `target/doc/`.

- [x] **`SPC m b D`** — `cargo doc --open`. Same, plus opens the generated
  docs in a browser — expect `Counter`'s doc comment to appear.

---

## Tests

- [x] **`SPC m t a`** — `cargo test`. Expect `increments_by_one` to pass.

- [x] **`SPC m t t`** — position inside `increments_by_one`, run just that
  test. Same pass expectation, narrower scope.

---

## Bench

- [x] **`SPC m b B`** — `cargo bench`. This flight-test defines no
  `#[bench]` targets (stable Rust's `cargo bench` needs either a nightly
  toolchain + `#![feature(test)]` or a benchmarking crate like `criterion`,
  neither of which this image installs) -- expect "no bench targets found"
  rather than an error. Confirms the keybinding itself invokes `cargo bench`
  correctly; not a real benchmark run.

---

## Not installed (will error if pressed)

- **`SPC m b a`** (`cargo audit`) and **`SPC m b o`** (`cargo outdated`) —
  both are Doom module bindings for optional cargo subcommands not part of
  this image's LSP+debugger scope (see `rust-keybindings.el`). Pressing
  either will fail with a "command not found"-style error; this is expected,
  not a regression.

---

## Checklist summary

| Group        | Bindings                                    |
|--------------|----------------------------------------------|
| LSP          | `K`, `g d`, `g D`, `SPC c r`, `SPC c a`, `] d`, `[ d`, `SPC b c` |
| Debug        | `SPC d d`                                    |
| Build        | `SPC m b b`, `SPC m b r`, `SPC m b c`        |
| Format/Lint/Doc | `SPC m f`, `SPC m b f`, `SPC m b C`, `SPC m b d`, `SPC m b D` |
| Tests        | `SPC m t a`, `SPC m t t`                     |
| Bench        | `SPC m b B`                                  |
