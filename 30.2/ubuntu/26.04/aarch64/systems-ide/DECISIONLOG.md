# Decision Log

---

## Rust debugging: lldb over gdb

**Date:** 2026-07-19
**Status:** Active (reaffirmed 2026-07-20 — see "Debugging: lldb hang was
DEBUGINFOD_URLS, not this host/arch" below for the full round trip. This
entry was briefly marked Superseded the same morning by a since-corrected
entry that misdiagnosed a hung environment variable as a fundamental
lldb-server incompatibility; that entry has itself been superseded, and
this decision stands as originally written.)

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

**Update (2026-07-20, morning):** The "free alternative" framing above
turned out to be wrong — lldb isn't actually usable as an alternative at
all on this host/arch (it hangs launching any binary, not just C/C++'s).
The "keep gdb as primary" decision itself is unaffected and still stands;
see "Debugging: lldb-server hangs on this host/arch; gdb becomes the sole
default for c/c++/rust" below for the full finding. lldb is no longer
offered in `SPC d d`'s menu for c-mode/c++-mode either.

**Update (2026-07-20, later the same day):** The hang above was
misdiagnosed — root-caused via `strace` as `DEBUGINFOD_URLS` (set by
Ubuntu's default profile), not a host/arch incompatibility. Fixed at the
image level; lldb is a working "free alternative" again, exactly as this
entry originally said. See "Debugging: lldb hang was DEBUGINFOD_URLS, not
this host/arch" below.

---

## Debugging: lldb-server hangs on this host/arch; gdb becomes the sole default for c/c++/rust

**Date:** 2026-07-20
**Status:** Superseded, same day — see "Debugging: lldb hang was
DEBUGINFOD_URLS, not this host/arch" below. Every empirical test recorded
here was real and reproduced correctly; the conclusion drawn from them
(a fundamental, host/arch-level lldb-server incompatibility) was wrong.
The privilege-level testing correctly ruled out capabilities/seccomp/
SELinux as the cause -- it just didn't occur to check environment
variables next, which is where the actual answer was.
**Related issue:** Supersedes "Rust debugging: lldb over gdb" above;
revises "C debugging: keep gdb as primary, lldb available as a free
alternative" above.

**Decision:** Route c-mode/c++-mode/rust-mode/rust-ts-mode/rustic-mode
through dape's `gdb` config exclusively. Clear `lldb-dap`/`lldb-vscode`'s
`modes` list entirely (empty -- not offered in `SPC d d`'s completion for
any mode here) rather than uninstalling the `lldb` apt package, which
stays.

**Rationale:** Empirically confirmed:
- `lldb` (raw CLI and dape's DAP-mode adapter both) hangs indefinitely
  trying to launch any compiled binary on this host/arch -- tested
  against both a cargo-built Rust binary and a CMake-built C binary.
  Confirmed under the container's default (zero extra) capabilities,
  under `--cap-add=SYS_PTRACE`, under `--cap-add=SYS_PTRACE
  --security-opt seccomp=unconfined`, and under full `docker run
  --privileged` (every capability, seccomp disabled, confinement
  disabled) -- the hang is identical regardless of container privilege
  level, ruling out a Docker capability/seccomp/SELinux restriction as
  the cause. Root cause not yet identified; under active, separate
  investigation.
- gdb works immediately with zero container/Dockerfile changes, on the
  exact same binaries. It hits the same underlying `personality()`
  ASLR-disable restriction lldb does in the container's default (no
  extra capabilities) config, but treats it as a non-fatal warning and
  proceeds anyway rather than aborting the launch.
- Verified live end-to-end via the actual `SPC d d` -> dape -> gdb DAP
  flow (not just raw CLI): breakpoint on `c.inc();` in the Rust
  flight-test, launch, correct stop at `flight_test::main` /
  `src/main.rs:17`, correct populated locals (`message "Hello"`, `c`
  present).
- Keeping `lldb` installed rather than removing it: negligible image
  size cost, and aarch64 container support for lldb-server may mature
  later. If the hang gets root-caused and fixed, re-adding
  rust-mode/rustic-mode/c-mode/c++-mode to `lldb-dap`'s `modes` in
  dape-config.el is a one-line revert.

**How it works:** see `dape-config.el` (extracted out of `config.el` as
its own file -- this is genuinely cross-language, not specific to any
one `:lang` module; also where the `:program` "a.out" fix lives).

**Revisit if:** the lldb-server hang gets root-caused and fixed, either
upstream or via a container-level workaround discovered here.

---

## Debugging: lldb was broken by two separate, fixable causes -- neither was the host/arch

**Date:** 2026-07-20
**Status:** Active
**Related issue:** Root-causes and reverses the entry above; reaffirms
"Rust debugging: lldb over gdb" and "C debugging: keep gdb as primary,
lldb available as a free alternative" as originally decided.

**Decision:** Two independent fixes, both applied, neither touching
container capabilities/seccomp/`run.sh`:
1. Clear `DEBUGINFOD_URLS` globally via `ENV DEBUGINFOD_URLS=""` in the
   Dockerfile.
2. Add `:disableASLR nil` to `lldb-dap`/`lldb-vscode`'s dape config in
   `dape-config.el`.

Revert `dape-config.el`'s `modes` changes from the entry above --
`gdb`/`lldb-dap`/`lldb-vscode` all keep their original, un-touched
default `modes` lists (lldb-dap covers rust-mode/rustic-mode/
rust-ts-mode plus c-mode/c++-mode; gdb covers c-mode/c++-mode/hare-mode).
The `:program` "a.out" fix from two entries back stays as-is -- always
correct, unrelated to either of these.

**Rationale, cause 1 (the hang):** `strace -f` on a hanging `lldb -b -o
run -o quit` showed no `ptrace`/`personality`/`fork` call anywhere near
the hang -- lldb was still inside `target create`, stuck in a socket
read/poll loop on a TLS connection to `91.189.92.252:443`, which resolves
to `debuginfod.ubuntu.com`. Ubuntu's `/etc/profile.d/debuginfod.sh` sets
`DEBUGINFOD_URLS` for every login shell; gdb explicitly prompts ("Enable
debuginfod for this session?") and auto-answers "no" when non-interactive
-- lldb has no equivalent prompt or default; it just tries the connection
and blocks indefinitely if it doesn't complete. `DEBUGINFOD_URLS=""`
turned a hang into a 0.2-second clean launch, confirmed via raw CLI and a
live daemon restart with the var cleared.

**Rationale, cause 2 (`personality set failed: Operation not
permitted`):** Clearing `DEBUGINFOD_URLS` alone was not sufficient --
confirmed the hard way, when a rebuild tested against the actual,
unmodified `run.sh` (zero extra capabilities, none of the `--cap-add`/
`--security-opt` flags from the earlier privilege-level testing) hit this
exact error again, the same one from the very start of this whole
investigation. It's the same underlying restriction gdb hits too (visible
there as a non-fatal warning) -- this container's default seccomp profile
denies the `personality()` syscall lldb-dap's launch handler calls to
disable ASLR before running the debuggee. Fixing this had looked, that
morning, like it required loosening the container (which is what the
now-reverted gdb-flip was actually working around). It doesn't:
`~/.lldbinit`'s `settings set target.disable-aslr false` and an
`initCommands` launch argument doing the same both run too late to matter
-- lldb-dap's ASLR-disable happens inside its own launch-request handling,
before either fires. `:disableASLR nil` is lldb-dap's own dedicated DAP
launch argument for exactly this, found by reading what arguments its
launch handler actually accepts rather than guessing at `~/.lldbinit`.
Setting it skips the syscall entirely -- no capability, no seccomp
override, no `run.sh` change of any kind.

**Verified, both fixes together, in the actual default container `run.sh`
launches** (not `--privileged`, not `--cap-add`, nothing -- a fresh
daemon in an otherwise-untouched container): the full `SPC d d` -> dape
-> lldb-dap DAP flow, breakpoint on `c.inc();`, correct stop at
`flight_test::main` / `src/main.rs:17`, and a complete, accurate backtrace
through Rust's runtime internals down to `_start`.

This was never a Docker capability/seccomp/SELinux/aarch64/16K-page-size
problem in the sense of "needs more privilege" -- the privilege-level
testing in the previous entry was real, and correctly showed that
`--privileged` didn't fix everything (because it couldn't fix cause 1,
the network hang, which has nothing to do with privilege at all). It
just meant the two causes got tangled together under a full-privilege
test that only ever addressed one of them, making the whole problem look
like a single unfixable host/arch issue when it was actually two
separate, ordinary bugs.

**Revisit if:** debuginfod support for system-library symbols (libc,
libstdc++, etc.) becomes something this image actually wants -- would
need a way to enable it that doesn't also reintroduce the hang (e.g. gdb's
own interactive-prompt behavior, or setting a shorter connect timeout
rather than clearing the URL entirely). Separately: if ASLR-enabled
debugging becomes actively wanted (rare -- mainly relevant to ASLR-related
security bugs), `:disableASLR nil` would need to flip back, and the
underlying container seccomp restriction on `personality()` would need
addressing for real at that point.

---

## lldb-dap ignores every breakpoint: a real dape race condition, fixed with `:stopOnEntry`

**Date:** 2026-07-20
**Status:** Active

**Decision:** Add `:stopOnEntry t` to `lldb-dap`/`lldb-vscode`'s config in
`dape-config.el`. `defer-launch-attach` stays at its default (unset).

**Rationale:** With the two fixes above in place, `SPC d d` stopped
erroring or hanging -- but breakpoints stopped working entirely instead,
100% reproducibly: the program always ran straight to completion, ignoring
even a single, freshly-set, correctly-placed breakpoint. Root-caused by
temporarily instrumenting `jsonrpc-connection-send`/`jsonrpc--log-event`
with live advice (dape explicitly disables jsonrpc's own events-buffer
logging, `:size 0`, so there's no built-in protocol trace to read) and
capturing the real request sequence directly from the user's live session:

```
id 1: initialize
id 2: launch          <-- sent immediately after initialize's response
id 3: setExceptionBreakpoints
id 4: setBreakpoints  <-- sent AFTER launch, too late
...
id 7: configurationDone
```

Reading `dape.el`'s actual source confirms this is a genuine race, not a
config mistake: the `initialize`-response handler sends `launch`
unconditionally (unless `defer-launch-attach` is set), on a code path
entirely independent of `setBreakpoints`/`configurationDone`, which only
fire once the adapter sends its own `initialized` *event*, whenever it
decides it's ready. These two paths aren't synchronized with each other.
If lldb-dap's `initialized` event arrives after `launch` has already taken
effect, breakpoints land too late.

`defer-launch-attach: t` -- dape's own documented, purpose-built escape
hatch for exactly this (its docstring cites "GDB bug 32090" as the
origin) -- does not fix it. Tested live: setting it causes a full stall,
`initialize` sent and then nothing else at all, not even
`setBreakpoints`. Working hypothesis: lldb-dap only emits `initialized` as
a side effect of already having received `launch` -- not independently,
the way the flag's design assumes -- so withholding `launch` until after
an `initialized`-triggered chain that itself never starts is a genuine
chicken-and-egg deadlock specific to this adapter.

`:stopOnEntry` sidesteps the race instead of fixing its timing.
Documented as a supported lldb-dap launch argument
(`lldb.llvm.org/use/lldbdap.html`), with existing precedent elsewhere in
dape.el's own built-in configs. With it set, the process always pauses at
its very first instruction (before any user code runs) regardless of
whether breakpoints have registered yet -- so the late `setBreakpoints`
request has as much time as it needs to land before anything resumes.

**Verified live, three separate times** (including once after a full
`./run.sh` container restart, ruling out any leftover-state explanation):
launch stops at entry (`signal SIGSTOP`, frame inside
`ld-linux-aarch64.so.1`), one `dape-continue` reaches the real breakpoint
correctly (`flight_test::main` / `src/main.rs:17`), with a full accurate
backtrace.

**Cost:** every `SPC d d` now stops once at the process entry point before
reaching any of your own breakpoints -- one extra `SPC d c` needed on
every launch. Worth it; the alternative was breakpoints not working at
all.

**Also learned the hard way**: mid-investigation, `emacsclient` stopped
responding entirely -- the main `emacs` process was in state `R` (actively
spinning, not blocked) with 16+ minutes of CPU time, alongside five
separate `lldb-dap`/`lldb-server` process pairs left over from earlier
test launches that were never cleanly disconnected. Attempting recovery
via `kill -SIGINT` on the container's PID 1 -- not realizing PID 1 *is*
Emacs itself in this image (`CMD ["emacs"]`, no separate init process) --
terminated the whole container instead of just interrupting the stuck
operation, losing all unsaved session state. The fix was already written
to `dape-config.el` on disk before this happened, so no investigation work
was lost, only the live session. Lesson: never signal a container's PID 1
without first confirming what it actually is (`docker exec <container>
cat /proc/1/comm`, or check the Dockerfile's `CMD`) -- and clean up debug
connections properly (`dape-kill`) rather than letting them accumulate
across repeated test launches.

**Revisit if:** this gets confirmed/reported upstream (`svaante/dape`) and
fixed there, at which point `:stopOnEntry` could potentially come back
out; or a cleaner workaround is found that doesn't require the extra
`SPC d c` on every launch.
