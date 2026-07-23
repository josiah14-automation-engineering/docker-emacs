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

---

## Lua debugging: local-lua-debugger-vscode over actboy168/lua-debug

**Date:** 2026-07-21
**Status:** Active

**Decision:** Use `tomblind/local-lua-debugger-vscode` as Lua's DAP debugger,
wired directly into `dape-configs` as a new `lua-local` entry in
`dape-config.el` (no dape built-in Lua config exists, unlike gdb/lldb-dap/
dlv/debugpy).

**Rationale:** `actboy168/lua-debug` is the more capable, more widely-used
option (proper coroutine support, broader Lua version coverage, used by
several Neovim `nvim-dap-lua` configs) but was rejected on distribution
grounds: its GitHub Releases page has been empty since 2019 (no prebuilt
binaries at all), and building it from source requires its own custom
`luamake` toolchain plus submodule dependencies -- the same shape of
fragile, hard-to-reproduce build this project has explicitly avoided
elsewhere (the CMake-language-server Python-version saga is the clearest
prior example). `local-lua-debugger-vscode` is pure TypeScript/Node with
exactly one runtime dependency (`vscode-debugadapter`) and builds with a
plain `npm install && npm run build` -- a normal, boring, reproducible
build, not a toolchain fight. Its one real limitation (no attach-to-
running-process support, launch only) doesn't matter for a personal dev
container where the launch is always under your own control anyway.

**How it works:** its debug adapter (`extension/debugAdapter.js`) is a
plain stdio DAP server, same shape as gdb/lldb-dap -- no socket/port
needed. Two things a normal VS Code install would inject automatically
and silently had to be supplied by hand: an explicit `:extensionPath`
launch argument (without it, the Lua-side `require('lldebugger')` fails
looking for `"undefined/debugger/lldebugger.lua"`), and its own nested
`:program` plist shape (`:lua`/`:file`, not a bare string). `+dape-lua-file`/
`+dape-lua-cwd` in `dape-config.el` use `buffer-file-name` directly rather
than dape's own project-root machinery (already known broken for nested
fixtures, see the Go/Rust/C entries above) or a marker-file walk -- a
debugged Lua script rarely has a project manifest to anchor one on in the
first place.

**Verified live:** breakpoint in the `for` loop of
`flight-tests/lua/init.lua`, correct stop, `name`/`value`/`hello_str`/
`options`/`utils` all populated in Scope, clean continue to completion.

**Revisit if:** `actboy168/lua-debug` ever ships real prebuilt release
binaries again, or coroutine-heavy debugging becomes something this tier
actually needs (out of scope for glue-script-adjacent Lua use so far).

---

## Python gets a real debugger; Ruby stays without one

**Date:** 2026-07-21
**Status:** Active

**Decision:** Install `python3-debugpy` via apt (not pip) for Python's
glue-script tier, giving it a working `SPC d d` via dape's already-built-in
`debugpy`/`debugpy-module` configs. Do not add an equivalent for Ruby.

**Rationale:** Both languages sit in the same glue-script tier (LSP on,
project tooling off, see "Python, Ruby, and JavaScript added as a
glue-script tier" in BUILDLOG.md) -- but lived experience with each
differs enough to justify treating their debugger needs differently
rather than applying the same rule uniformly. Python glue scripts here
tend to be larger and more failure-prone in practice (real deploy/task
scripts, not one-liners) -- exactly the kind of thing where a real,
structured debugger (breakpoints, scope inspection, step execution) pays
for itself. Ruby glue scripts (Chef-style) haven't shown the same need in
practice -- and Ruby already has a perfectly serviceable, zero-extra-
dependency answer if one ever comes up: `binding.pry`, run through Doom's
existing `inf-ruby` REPL integration (already wired for plain `irb`; pry
is a drop-in replacement speaking the same comint protocol). That's a
REPL-driven debugging session, not a structured dape one -- deliberately
a different, lighter-weight shape than what Python is getting here, not a
worse version of the same thing.

`python3-debugpy` was chosen over `pip install debugpy` specifically to
keep the "no pip/poetry/conda" rule for this tier intact (see the
Dockerfile's glue-script-tier comment) -- Ubuntu's `universe` repo
packages it as an `Architecture: all` package (pure Python, no per-arch
build needed), so apt covers it exactly the way ruff/pyright/ruby-lsp
already cover everything else in this tier, without an exception to the
tier's own stated philosophy.

**A real gap found along the way:** this image ships only a versioned
`python3`, no bare `python` -- and dape's built-in `debugpy` config
hardcodes `command "python"`. Without a symlink, the adapter simply
isn't found. Fixed the same way the identical `lua`/`lua5.4` gap was
fixed for Lua: `ln -s /usr/bin/python3 ~/.local/bin/python`.

**Verified live:** breakpoint inside `main()` in
`flight-tests/python/deploy.py`, correct stop, clean continue through
`import tasks`/the rest of the script to a clean exit. Also noted for the
record (technically present, not actually harmful): dape's built-in
`debugpy`/`debugpy-module` configs resolve `:program`/`:cwd` via
`dape-buffer-default`/`dape-cwd`, which -- like gdb/lldb-dap/dlv before
the earlier command-cwd fixes -- ultimately call the same broken
`project-current` chain for a project nested inside this repo's own git
tree. Unlike those three, this turns out to be harmless here: both
`:program` and `:cwd` derive from the exact same (wrong, but internally
consistent) root value, so the relative path and the working directory
still combine to the correct absolute file. No fix applied; flagged here
in case a future dape/debugpy version changes how these are computed
relative to each other.

**Revisit if:** Ruby glue-script debugging needs ever actually come up in
practice, or `debug.rb`'s own DAP server mode (bundled with Ruby 3.1+)
becomes worth wiring in as a structured alternative to pry.

---

## LSP workspace-root detection: teach Projectile about this project's own build-system markers

**Date:** 2026-07-21
**Status:** Active

**Decision:** Add `Cargo.toml`, `go.mod`, and `CMakeLists.txt` to
`projectile-project-root-files-bottom-up` in `config.el` (a new
`(after! projectile ...)` block, grouped under a new "LSP adjustments"
section header alongside the pre-existing `(after! lsp-mode ...)`
block).

**Rationale:** `lsp-auto-guess-root` (already `t`, see the entry above)
resolves the workspace root via `projectile-project-root` -- and
Projectile's own bottom-up marker list, which correctly handles a
project nested inside a bigger VCS tree by returning the closest match,
ships with only version-control markers by default. Every "full
support" tier flight-test fixture in this repo (all nested inside this
repo's own git tree, by construction) resolved to the outer repo root
instead of their own project directory: rust-analyzer, gopls, and
clangd all silently initialized against the wrong workspace. Same root
cause as the debugger-side command-cwd bug fixed earlier tonight (see
"Fix the same command-cwd bug for gdb/lldb-dap/lldb-vscode, not just
dlv" and the Go/dlv entry before it) -- this is the LSP-side half of the
identical underlying issue, caught later specifically because dape's
debugger configs already bypass project/projectile entirely for their
own `:program`/`command-cwd` resolution, while LSP root-guessing goes
straight through Projectile with no such bypass.

**A real tradeoff, considered and accepted rather than assumed away:**
bottom-up search returns the *closest* marker match. A genuine
multi-module CMake project (umbrella `CMakeLists.txt` with
`add_subdirectory()` subprojects, each with their own nested
`CMakeLists.txt`) would resolve to the innermost subdirectory instead of
the umbrella root. The alternative --
`projectile-project-root-files-top-down-recurring` (returns the
*outermost* match, already used for `compile_commands.json`/`Makefile`)
-- was considered and rejected: it trades this failure mode for the
opposite one, incorrectly swallowing a genuinely separate, accidentally-
nested unrelated project into a larger one. Rust and Go are considerably
less exposed to this in practice than C/CMake -- rust-analyzer and gopls
both self-discover their true workspace root from workspace-aware
manifests (`Cargo.toml`'s `[workspace]`, `go.work`) once pointed at any
member, independent of what directory `lsp-mode` initially guessed;
clangd's own `compile_commands.json` discovery walks up from the source
file independently of the LSP-reported root, which may make it more
tolerant of this than expected, but this specific claim wasn't verified
live against a real multi-module CMake project. Likelihood assessed as
low for this project specifically: none of the current flight-test
fixtures have this shape.

**Cross-util jump-to-def (a related but separate concern):** for a
future repo containing several small language-specific utils that
cross-reference each other (e.g. one C utility linking against
another), this fix only governs the automatic, zero-effort root guess
-- it doesn't preclude explicitly telling lsp-mode about a broader
scope. Rust/Go both have native, purpose-built answers independent of
this heuristic entirely (Cargo workspace members, `go.work`). C/CMake
has no equivalent workspace manifest; the answer there is either one
umbrella `CMakeLists.txt` with `add_subdirectory()` (one build, one
`compile_commands.json`, one clangd session automatically), or manually
calling `lsp-workspace-folders-add` to add a second directory into the
same clangd session -- a normal, supported multi-root workflow already
built into lsp-mode, not something needing new configuration here.

**How to manually override the guessed root:** `lsp-auto-guess-root`
being globally `t` short-circuits `lsp-mode`'s own interactive root
picker (`lsp--find-root-interactively`) -- confirmed by reading
`lsp--calculate-root`'s `or` chain, which tries
`lsp--suggest-project-root` first and only reaches the interactive
prompt when auto-guess is off. `M-: (setq-local lsp-auto-guess-root
nil)` in the buffer in question, then `M-x lsp`, reaches the real
prompt (import suggested root / select root directory interactively /
import at current directory / blocklist) -- buffer-locally, without
touching the global setting the daemon/smoketest flow depends on.

**Follow-up decision, same session:** wrapped the recipe above into two
real commands (`lsp-pick-root`, `lsp-restore-auto-guess-root`) in a new
`polyglot-keybindings.el` -- a new category of file, distinct from both
`global-keybindings.el` (purely editor-level) and each language's own
`<lang>-keybindings.el`: cross-cutting development-tooling concerns that
show up across multiple languages' LSP/project setups but aren't
specific to any one of them. `SPC c l w S` for the picker. Considered
having `lsp-pick-root` write a `.dir-locals.el` itself (verified live
that setting `lsp-auto-guess-root` to `nil` per-project via
`.dir-locals.el` correctly makes every subsequent file resolve to the
already-picked root automatically) -- deferred, not yet built.

**A related decision found along the way:** Doom's `map!` has no
`(declare (indent N))`, and `:prefix' isn't a real special form, so
nested `:prefix` forms indent with cascading offsets by default. Fixed
globally via `(put ':prefix 'lisp-indent-function 1)` in a new
`all-lisps-config.el` (distinct from `config.el`'s per-language files --
scoped to Lisp-editing behavior that should apply across every Lisp
dialect this setup touches, not one language's toolchain). Numeric `1`
chosen over `'defun` after testing both live: both give the same clean,
non-cascading per-level nesting step, but only `1` also lines up a
form's own body with its one positional argument (e.g. `:desc` aligning
with `:prefix` in `(:prefix "w" :desc ...)`). Confirmed this property is
process-wide, affecting `lisp-mode`/`scheme-mode` too, not just
`emacs-lisp-mode` -- accepted given `:prefix`-as-list-head is a
distinctly Doom/Emacs-Lisp DSL pattern, unlikely to collide with
idiomatic Common Lisp/Scheme/Racket code, relevant given Guile/SBCL/
Racket/scsh/rash support under consideration. A genuine per-project
override remains possible without touching this global property:
`calculate-lisp-indent` reads it through an ordinary, buffer-local-able
`defcustom` also named `lisp-indent-function` (confusingly, the same
name as the property) -- a project's own `.dir-locals.el` can rebind
that variable instead, the same way `lsp-auto-guess-root` already does.

**Verified live:** rust-analyzer/gopls/clangd all correctly resolve to
their own flight-test subdirectory (not the repo root) after the fix,
against this repo's own nested copies. Only verified on aarch64 so far.

**Revisit if:** a real multi-module CMake project (or Cargo/Go workspace
with the same nested-manifest shape) is ever opened in one of these
containers and the closest-match behavior turns out to be wrong for it
in practice.

---

## Guile's Guile comes from a standalone `guix-source` image, not plain apt

**Date:** 2026-07-21
**Status:** Active

**Decision:** `systems-ide` gets `guile` (and `guix`) via
`COPY --from=guix-source`, a new standalone image, rather than
`apt-get install guile-3.0`.

**Rationale:** Initial recommendation was plain apt: Ubuntu's
`guile-3.0` (3.0.11-2) and Guix 1.5.0's own bundled Guile (3.0.9,
confirmed live) are close enough in version that a version-freshness
argument for the Guix-sourced route seemed weak, and plain apt avoids
extra image-build complexity. **Reversed after being directly
challenged on it:** is version parity actually guaranteed to hold, or
is it a coincidental snapshot? It's the latter -- Ubuntu freezes apt
packages at release time; Guix keeps moving forward with each release.
More importantly, the actual intended use is working with Guix's own
package/channel definitions through Geiser, which needs Guix's own
Guile module load path, not just a version-matched but otherwise
unrelated apt binary. Guix's own historical Guile-version maintenance
is also solid (promptly adopted the 2.2→3.0 transition in 2020, keeps
shipping point-release bumps) -- not a stale or neglected dependency to
avoid coupling to.

**A second reversal, this one self-corrected before implementation:**
assumed getting `guile` out of the tarball would need a transient
`guix-daemon` running during the image build (`guix install guile`),
the single riskiest, least-precedented step originally planned for this
work. Verified live it isn't needed at all: Guix is itself implemented
in Guile, so a full Guile closure is already a transitive dependency of
the `guix` package sitting in the store right after plain tarball
extraction -- it's just not symlinked into `guix`'s own profile `bin/`
by default. A build-time-discovered symlink is all that's needed; no
daemon, no `guix install`, at build time at all.

**Revisit if:** a future Guix release changes its own Guile version in
a way that breaks Geiser/geiser-guile compatibility, or the manual
symlink-discovery approach breaks against some future Guix release's
store layout.

---

## Guix daemon architecture: in-container, not bridged to a host daemon

**Date:** 2026-07-21
**Status:** Superseded 2026-07-22 -- see "Guix daemon architecture:
host-bridged by default, in-container as a toggle" below. The
either/or framing here was itself a mistake, corrected directly by the
user: `MOUNT_HOST_NIX` already proves (for Nix, elsewhere in this same
file) that host-bridged and self-contained aren't mutually exclusive
architectures, just two ends of one runtime toggle. Everything below
about the sandbox-capability flags and the `sudo`/`secure_path` bug
still applies unchanged to the self-contained fallback path.

**Decision:** `systems-ide` runs its own `guix-daemon` as a background
process at container *runtime* (new `entrypoint.sh`), rather than
bridging to a `guix-daemon` running on the host or in a sidecar
container.

**Rationale:** Original design modeled this on the existing
Docker/Podman client-bridge pattern already in this project (client
only in the container, daemon lives outside, `run.sh` bridges via a
socket). **Reversed when the user pointed out the actual failure
mode:** unlike Nix (fully self-contained -- packages are baked into
`/nix` at build time via single-user `--no-daemon` mode, so the running
container never depends on any daemon being reachable) or Docker/Podman
(bridging to an external daemon is the entire point -- avoiding
Docker-in-Docker), a Guix host-daemon bridge would make `systems-ide`'s
Guix functionality entirely dependent on an external `guix-daemon`
staying reachable, with zero in-container fallback if it isn't -- a
real resilience regression against every other package manager this
project supports, not a minor gap. Running the daemon inside the
container instead sidesteps the actual constraint that motivated the
bridge design in the first place: "can't fork a persisting daemon
during a Docker `RUN` layer" is a constraint on `docker build`, not on
an already-running container, so there was never a real reason Guix
needed the bridge architecture Docker/Podman use for an unrelated
reason (avoiding nested container engines).

**Security posture, addressed directly rather than glossed over:**
making this work needs `--security-opt seccomp=unconfined`, `--cap-add
SYS_ADMIN`, and `--cap-add NET_ADMIN` (Guix's build sandbox calls
`personality()`, `clone()`, and brings up its own loopback interface in
a fresh network namespace -- all three blocked by different Docker
defaults, discovered one at a time as each fix uncovered the next
blocker further into a real build; see BUILDLOG.md for the exact
failure modes). Raised and discussed directly: `systems-ide` already
bridges `docker.sock`, and reaching that socket at all is already
equivalent to host root (`docker run -v /:/host --rm -it alpine chroot
/host`, confirmed as the standard mechanism, not project-specific) --
so none of the three flags are a new category of risk, only a
comparatively small widening of what can already reach that same
ceiling. Also noted directly: the realistic alternative to running this
in a container isn't "no such privilege exists" -- it's running the
same Guile/Guix tooling directly in host-installed Emacs, which already
carries the identical docker-group-implies-root exposure with no
container involved at all.

**A separate bug, unrelated to any of the above, found only once
testing against the real `systems-ide` image:** `entrypoint.sh`'s
`sudo guix-daemon ...` failed with "command not found" -- `sudo` resets
`PATH` to its own `secure_path` by default, which doesn't include
`~/.local/bin` (where `guix-daemon` is symlinked). Fixed with an
absolute path (`sudo "$HOME/.local/bin/guix-daemon"`) rather than
relying on PATH lookup through `sudo`.

**Revisit if:** this project's security posture changes (e.g. adopting
rootless/more isolated container tooling generally), or Guix ships a
build-sandbox mode that doesn't need `personality()`/`clone()`.

---

## Guix daemon architecture: host-bridged by default, in-container as a toggle

**Date:** 2026-07-22
**Status:** Active

**Decision:** `run.sh` (both aarch64 and x86_64 trees) gained a
`guix_mounts` array mirroring `nix_mounts`'s `MOUNT_HOST_NIX` toggle
exactly: `MOUNT_HOST_GUIX` (default `1`) bind-mounts the host's real
`/gnu:ro` and `/var/guix` (read-write) in, so `systems-ide` shares the
host's actual store and daemon by default. `entrypoint.sh` detects the
bridge itself via the daemon socket's presence
(`/var/guix/daemon-socket/socket`) and skips starting its own daemon +
substitute-key authorization when it's active, falling back to the
previous entry's self-contained behavior only when
`MOUNT_HOST_GUIX=0` or the host has no `/gnu` at all.

**Rationale:** The previous entry framed self-contained-vs-bridged as
a one-time architectural choice. That framing was wrong: this exact
project's own `MOUNT_HOST_NIX` toggle already demonstrates both
properties -- shared host state by default, resilient fallback when
the host's install is broken -- can coexist behind one runtime switch,
not an either/or. Guix's version needed no `ldd`-based host-binary
bridging wrapper the way Nix's does (Nix's binary lives outside `/nix`
on this host, requiring `.host-nix-bridge`); Guix's own binary lives
inside `/gnu/store`, and because the store is content-addressed, the
container's build-time-baked `guix`/`guile` symlinks keep resolving
correctly once the host's `/gnu` is bind-mounted over the container's
local one -- confirmed live before writing any code, via a standalone
`docker run -v /gnu:/gnu:ro -v /var/guix:/var/guix` test against the
real host daemon.

**Verified live, both paths, against the real rebuilt image:** bridged
mode reached the host daemon with zero extra config (`guix` finds the
socket at its own default path once `/var/guix` lands at the same
path) and a `guix install tree` run from inside the container showed
up in the *host's* real profile afterward; self-contained mode (no
host mounts, same sandbox-capability flags as before) started its own
daemon, authorized both substitute keys, and completed a `guix install
hello` + ran the resulting binary. Full smoketest: 78/78, no
regressions. See BUILDLOG.md for the full transcript.

**Revisit if:** Guix ships a way to detect a stale/mismatched host
store (e.g. a host `guix pull` mid-upgrade) that should trigger an
automatic fallback rather than requiring `MOUNT_HOST_GUIX=0` by hand.

---

## Guile flight-test's load-path fix: whitelist one `.dir-locals.el` form, don't disable eval trust wholesale

**Date:** 2026-07-22
**Status:** Active

**Decision:** Add the exact form `(add-to-list 'geiser-guile-load-path
default-directory)` to `safe-local-eval-forms` in `config.el`, rather
than setting `enable-local-eval` to `t`.

**Rationale:** The flight-test fixture's own module-loading idiom
(`(add-to-load-path (dirname (current-filename)))`) doesn't work under
Geiser's per-form evaluation (see BUILDLOG.md 2026-07-22 for the full
mechanism) -- the fix needed `.dir-locals.el` to reference
`default-directory` dynamically, which requires an `eval' clause.
Emacs prompts to trust unfamiliar `eval` dir-locals by default, which
would hang a headless smoketest run. The tempting shortcut --
`enable-local-eval t` -- was proposed and directly rejected: it trusts
`eval` forms in *every* `.dir-locals.el` this Emacs instance ever
opens, in any project, not just this repo's own fixture. Whitelisting
the one exact form via `safe-local-eval-forms` keeps the trust boundary
scoped to something this repo's own smoketest actually needs.

Same underlying reasoning already applied earlier this session to the
Guix build sandbox's `seccomp`/`SYS_ADMIN`/`NET_ADMIN` requirements
(match the scope of a security relaxation to what's actually needed,
don't reach for the broadest available bypass) -- worth noting this
one wasn't proposed proactively; the user caught it directly when a
tool call attempted the broader `enable-local-eval` change.

**Revisit if:** more `.dir-locals.el` files with `eval` clauses
accumulate across this project to the point where whitelisting each
one individually becomes real maintenance overhead.

---

## Fish and Assembly upgraded to full LSP; Perl kept deliberately syntax-only

**Date:** 2026-07-22
**Status:** Active

**Decision:** Of ROADMAP's original "syntax-only batch" (Fish, Assembly,
Perl), Fish and Assembly both got full LSP support (`fish-lsp`,
`asm-lsp`) instead of the originally-scoped plain syntax highlighting.
Perl stayed syntax-only on purpose.

**Rationale:** Research surfaced real, actively-maintained language
servers for both Fish and Assembly that this project's own tooling
(`lsp-mode`) could reach with comparatively little added surface --
`asm-lsp` even ships a built-in `lsp-mode` client already, needing only
a forced `require`, no manual client registration. Given that low
marginal cost, upgrading both was a straightforward call. Perl was the
opposite: not a technical gap (perl-language-server/PLS options exist)
but an explicit product decision -- "I hate Perl, code in it is usually
a mess, I want to discourage Perl use." Kept as-is: `perl` already
ships as a transitive apt dependency of something else in the image,
and `perl-mode` + its `.pl`/`.pm` mapping both ship built into Emacs
core, so "syntax-only" here needed zero code changes at all, not even
an explicit apt install.

**Per-tree Dockerfile divergence for asm-lsp, not an oversight:**
aarch64 has no prebuilt Linux/aarch64 `asm-lsp` release (confirmed
against the actual GitHub release assets), so it's built via `cargo
install` after the Rust step, needing `pkg-config`/`libssl-dev` added
to the apt list for `openssl-sys` (confirmed live: the build fails
without them). x86_64 has a real prebuilt Linux binary, so that tree
uses the prebuilt-tarball pattern instead, matching ruff/stylua, with
no Rust-toolchain coupling at all. Two different install mechanisms
for the same tool, in the two trees, on purpose.

**A process lesson, not just a product one:** two of the three
version-check tests written for this batch were wrong on first pass
(`asm-lsp --version` isn't a valid invocation -- it's a clap subcommand
CLI, needing `asm-lsp version` instead) and the LSP-connection test for
Assembly failed *consistently* in the full suite while passing in
isolation -- root-caused to `go-mode.el`'s own `magic-mode-alist`
predicate (`go--is-go-asm`) silently hijacking `.s` files into
`go-asm-mode` whenever the same directory holds a `.go` file, which
this project's own Go fixture (`test.go`) does. Prompted directly:
"let's not have failing tests failing for cosmetic reasons, fix the
tests so that they aren't vulnerable to the same kind of cosmetic
quirks in the future" -- applied to two *other*, longer-standing
pre-existing failures too (`vcpkg` version string, `.h` file mode),
both traced to the same underlying class of bug (a shared flat fixture
directory where one language's mode-detection heuristic gets confused
by another language's sibling files), not random flakiness. See
BUILDLOG.md for the full root-cause trail on all four.

**Revisit if:** Perl's "discourage use" framing changes (e.g. if a
legacy Perl codebase actually needs to be worked on inside this IDE),
or `asm-lsp`/Rust ships a Linux/aarch64 release, letting that tree
switch off `cargo install` too.

---

## Haskell: syntax-only in systems-ide, full LSP deferred to its own IDE

**Date:** 2026-07-22
**Status:** Active

**Decision:** `systems-ide` will not get Haskell Language Server (HLS)
support. If Haskell is added here at all, it's syntax-only highlighting
(`haskell-mode`/tree-sitter, no `lsp-mode`, no debugger). Full LSP +
debugging support belongs in its own dedicated, refreshed IDE image
instead — reviving the stale `29.2/ubuntu/22.04/x86_64/haskell-ide/` as
a modern 30.2 build is the likely path, whenever that's picked up.

**Rationale:**
- This mirrors an existing, already-established pattern in this repo:
  Mercury, Python, and Scala all get their own per-language IDE
  directories rather than being folded into a shared polyglot image,
  specifically because their tooling needs are heavier or more
  specialized than what a shared image comfortably supports. HLS fits
  that same shape — multi-package cabal/stack project resolution and
  tight GHC-version coupling make it a heavier, more failure-prone
  dependency than the LSP servers already in `systems-ide` (gopls,
  rust-analyzer, clangd, racket-langserver, etc.), all of which are
  single-binary or single-package-manager installs with no comparable
  project-resolution complexity.
- Concrete, first-hand history, not hypothetical caution: Josiah has
  had Haskell fully working in a past Doom Emacs configuration before
  and had it "inexplicably break," with no root cause ever isolated.
  That's a specific, painful precedent for Haskell tooling in Emacs
  specifically, distinct from this repo's general "verify before
  assuming" discipline (see AGENTS.md) — the caution here is earned by
  a real incident, not applied by default.
- A dedicated image also isolates the blast radius: if HLS breaks again
  the way it apparently has before, that's contained to one throwaway
  IDE image rather than jeopardizing every other language sharing
  `systems-ide`'s single Doom config and package set.

**Not a factor:** Haskell's standing as a systems-programming language
in the abstract — that question was settled separately (XMonad is real
systems evidence; Turtle is shell-scripting-DSL tier, not systems
evidence) and doesn't change this decision either way. This entry is
purely about where HLS tooling should live, not whether Haskell
"counts."

**Revisit if:** `systems-ide` picks up Haskell for real (syntax-only
first — full LSP still requires deciding whether to revive
`haskell-ide` or build fresh), or HLS's own reliability/setup story
changes enough to reopen the "heavier dependency" argument above.

