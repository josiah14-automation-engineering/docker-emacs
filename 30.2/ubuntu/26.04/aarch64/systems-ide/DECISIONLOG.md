# Decision Log

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


