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
