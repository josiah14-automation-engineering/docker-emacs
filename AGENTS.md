# Agent Guide: Lessons From Debugging This Project

Complements `CLAUDE.md` (what the project *is*). This is *how to work on
it well* — checks worth running before assuming a new integration is
solid. Each entry: **Rule** (do this) then **Why** (compressed reason).

## 1. Project-root detection

**Rule:** Before calling a new language integration done, check whether
every tool it wires up (LSP client, debugger, formatter) resolves its
own "project root" independently, and whether each one routes through
Projectile/`project.el`. If the language's manifest file isn't in
`projectile-project-root-files-bottom-up` (`config.el`, "LSP
adjustments"), add it. Separately check whether the debugger config
needs its own bypass too (`dape-config.el`'s
`+dape-resolve-cwd`/`+dape-go-root` pattern).
**Why:** Doom prepends `project-projectile` ahead of `project.el`'s own
VC backend in `project-find-functions`, and
`projectile-project-root-files-bottom-up` ships with only
version-control markers — missing `Cargo.toml`/`go.mod`/`CMakeLists.txt`.
Any file under this repo's nested `flight-tests/<lang>/` fixtures hits
this. Already bit twice, independently, at two layers for the same
languages: dape's `command-cwd` resolution, and separately `lsp-mode`'s
`lsp-auto-guess-root` → `lsp--suggest-project-root` →
`projectile-project-root`. Fixing one layer doesn't fix the other.

## 2. "Wired up" ≠ "verified working"

**Rule:** Every new language integration needs a live end-to-end test —
breakpoint set, program launched, continued, scope inspected with real
values. Not "config loads without error," not "package installed."
**Why:** A `dape-configs` entry existing doesn't mean it launches. An
installed LSP client doesn't mean it resolves the right root.

## 3. Test the nested case on purpose

**Rule:** Keep validating new languages against fixtures nested inside
`docker-emacs`'s own git tree (`flight-tests/<lang>/`), not only a
standalone copy (`~/flight-tests/`).
**Why:** The nested shape is what actually exposes project-root bugs — a
standalone copy never exercises that code path.

## 4. A familiar symptom is not a diagnosis

**Rule:** When a bug's symptom matches one already fixed, verify the
cause before assuming it's the same fix. Don't skip re-diagnosis.
**Why:** "Can't find Cargo.toml" came from two unrelated subsystems in
one session — dape's `command-cwd`, and separately LSP's
`project-current`/Projectile chain.

## 5. Know whether you're touching global or scoped state

**Rule:** Before promising a fix can be "scoped down later if needed,"
check whether it's a symbol property (`put`, process-wide, no clean
per-project override) or a `defcustom` variable (buffer-local-able,
works with `.dir-locals.el`).
**Why:** `:prefix`'s `lisp-indent-function` *property* (`all-lisps-
config.el`) is global with no isolation between buffers. The
identically-named `lisp-indent-function` *variable* that reads it is an
ordinary buffer-local-able `defcustom` — different mechanism entirely,
easy to conflate because of the shared name.

## 6. Doom-specific precedence isn't documented upstream

**Rule:** Remember `project-projectile` outranks `project.el`'s own VC
backend in `project-find-functions`, explicitly, rather than
re-deriving it from scratch each time a root-detection bug shows up.
**Why:** This is Doom-specific, not vanilla Emacs or vanilla `lsp-mode`
— generic docs/answers won't mention it, and it explains most
"why doesn't the standard fix work" confusion in this setup.

## 7. Re-audit config file placement as languages accumulate

**Rule:** Language-specific settings go in `<lang>-config.el`, never
directly in `config.el`'s shared `after!` blocks. Cross-language config
either stays in `config.el` directly, or — if it's substantial code
around one specific tool (see `dape-config.el`) — gets its own file. Do
a placement check whenever a new language lands.
**Why:** Ruby/Python settings scattered into `config.el` directly and
only got caught when Lua's addition made the accumulation obvious.

## 8. Clear caches before trusting a verification result

**Rule:** When verifying a root-detection or LSP fix, explicitly clear
`project.el`'s cache, Projectile's cache, or start from a genuinely
fresh buffer — don't trust an ambiguous result from reused state.
**Why:** All three (plus dape's history pre-fill) have independently
caused "it worked, then broke, then worked again" false signals.

## 9. New `.el` files need three things, every time

**Rule:** The file itself, a `(load! "the-file")` line in `config.el`,
and a `COPY` line in *both* Dockerfiles. Check all three before calling
a new file done.
**Why:** Any one missing means the file silently never loads in a
rebuilt image — easy to forget mid-flow.

## 10. Default to boring, reproducible dependencies

**Rule:** For a new language's tooling (debugger, formatter, LSP
extras), prefer a plain `apt`/`npm`/`pip`-installable dependency over a
more feature-complete one that needs a fragile, hand-rolled build.
**Why:** `local-lua-debugger-vscode` (plain `npm install`) was chosen
over the more capable `actboy168/lua-debug` specifically because the
latter has a dead release pipeline and its own custom build toolchain.
Same judgment call this project makes repeatedly.

## 11. Shared smoketest fixtures can cross-contaminate mode detection

**Rule:** When a new language's fixture goes into `/tmp/smoketest/`,
check whether any major-mode heuristic in the image inspects sibling
files or directory contents (not just the file's own name/extension)
before assuming a fresh fixture is isolated from every other language's.
**Why:** `go-mode.el`'s own `magic-mode-alist` predicate
(`go--is-go-asm`) silently activates `go-asm-mode` instead of plain
`asm-mode` for any `.s` file whose *directory* contains a `.go` file —
this repo's own flat fixture directory (holding `test.go` for the Go
tests) tripped this for the assembly fixture. Separately, Emacs's own
`c-or-c++-mode` disambiguates an ambiguous `.h` via a same-*basename*
`.c`/`.cpp` sibling — this repo's own `test.h`/`test.cpp` pair did the
same thing. Two different mechanisms (directory-content sniffing vs.
basename matching), same root shape: one language's fixture silently
breaking another's test. Fix is the same each time — isolate into a
dedicated subdirectory, or rename off the colliding basename — but the
bug is easy to mistake for "flaky" rather than 100% deterministic.

## 12. A root/cwd resolver's fallback needs testing as much as its happy path

**Rule:** For any per-language `command-cwd`/root resolver that walks up
for a marker file (`+dape-resolve-cwd`, `+dape-go-root`, etc.), test the
*zero-markers-found* case explicitly, not just "marker exists" and
"wrong marker resolves." Don't assume the existing fallback
(`dape-command-cwd` or similar) degrades gracefully.
**Why:** `+dape-resolve-cwd`'s fallback silently resolved to the literal
broken string `"//"` when no `Cargo.toml`/`CMakeLists.txt` existed
anywhere up a file's directory tree — not "the wrong root," a
nonexistent one. gdb then never found the relative `:program "a.out"`,
every breakpoint sat "pending" forever, and every adapter output/events
buffer stayed completely empty — no error surfaced anywhere. Every
language that had already used this resolver (C/C++/Rust) always has a
manifest file, so this path was never exercised until Assembly (which
has no manifest convention at all) hit it first.

## 13. Verify a CLI tool's actual invocation shape before writing a test against it

**Rule:** Before asserting `<tool> --version` (or any other flag) in
`smoketest.bats`, run the tool directly and read its own `--help`/error
output. Don't assume a flag that works for most CLI tools works for this
one.
**Why:** `asm-lsp --version` errors outright ("unexpected argument") —
it's a clap subcommand CLI (`asm-lsp version`, not a flag) —
confirmed only by actually running it. Separately, `vcpkg version`
reports vcpkg-*tool's* own build date, not the `VCPKG_VERSION`
ports-registry tag this project pins — two different, independently
versioned things that happen to look like the same kind of "version
string." Both wrong assumptions would have shipped as permanently
failing (or permanently wrong-but-passing) tests if not checked live.

## 14. Diagnosing a headless daemon that "isn't doing anything" has two very different causes

**Rule:** When a scripted `emacs --daemon` + `emacsclient --eval`
sequence appears to hang or silently not launch something, check
`ps aux` inside the container and the target's own output/events buffers
directly before concluding it's broken. Don't just wait longer or retry
blindly.
**Why:** Two unrelated causes produce the identical symptom in this
project's own verification workflow: (1) a *genuinely still-working*
daemon burning its first real seconds on Doom's own async
native-compilation backlog (several `emacs -Q --batch` subprocesses
compiling `.el` files in parallel), starving the single-threaded main
Emacs of cycles to process async responses — looks exactly like a hang
if checked too soon; (2) a genuinely *stuck* recursive minibuffer edit
from a test harness that inserted text via `minibuffer-with-setup-hook`
but never sent a terminating RET — a real bug in the test script, not
the thing under test. `ps aux` (is the target process actually running
and in what state?) and reading the relevant `*dape-...*`/`*eval*`
buffers directly distinguish the two immediately; guessing does not.

