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

---

## Nix store bind mount: conditional detection, read-only/write split, MOUNT_HOST_NIX escape hatch

**Date:** 2026-06-16
**Status:** Active

**Decision:** Bind-mount the host's `/nix` store only when it exists (`[[ -d /nix ]]`), using a RO/RW split that keeps store contents immutable while allowing Nix's mutable bookkeeping. Provide `MOUNT_HOST_NIX=0` to opt out without touching the host's filesystem.

**Mount pattern:**

| Path | Mode | Reason |
|---|---|---|
| `/nix` | `:ro` | Store contents immutable; prevents container writes to the host store |
| `/nix/var/nix` | rw | Nix acquires `gc.lock` and writes `temproots` for any store operation; `:ro` here produces EBADF on lock acquisition |
| `/nix/var/nix/profiles` | `:ro` | `nix develop` writes to `gcroots/auto`, never to `profiles`; writable profiles = container can tamper with host profile generations |
| `~/.config/nix` | `:ro` | Config updates go through the host |
| `~/.local/state/nix` | `:ro` | Profile updates go through the host |

**Why conditional, not unconditional:** The `nix-source` COPY stage bakes a working `/nix` store into every image. When the host `/nix` is absent (or `MOUNT_HOST_NIX=0`), the container runs self-contained on that store — useful during host Nix outages, mid-upgrade states, or when evaluating a new IDE image before the host is wired up.

**Why `MOUNT_HOST_NIX` in addition to `[[ -d /nix ]]`:** The directory guard is insufficient for a corrupt or mid-upgrade host store — `/nix` exists as a directory in both cases. The env var provides an explicit opt-out that doesn't require filesystem surgery on the host.

**Revisit if:** A per-container Nix daemon eliminates the need for host-store sharing.

---

## Rust debugging: lldb over gdb

**Date:** 2026-07-19
**Status:** Active (reaffirmed 2026-07-20 — see "Debugging: lldb hang was
DEBUGINFOD_URLS, not host/arch" below for the full round trip. This entry
was briefly marked Superseded the same day, mirroring an aarch64 entry
that misdiagnosed a hung environment variable as a fundamental lldb-
server incompatibility; that entry has itself been superseded, and this
decision stands as originally written.)

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
turned out to be wrong on the aarch64 build (lldb isn't actually usable
there at all, hanging on any binary, not just C/C++'s) -- and this tree
preemptively followed suit without independent x86_64 verification. The
"keep gdb as primary" decision itself is unaffected and still stands;
see "Debugging: lldb-server hangs on the aarch64 build host; gdb becomes
the sole default for c/c++/rust here too" below for the full finding and
the caveat about this tree specifically. lldb is no longer offered in
`SPC d d`'s menu for c-mode/c++-mode either, pending its own
verification here.

**Update (2026-07-20, later the same day):** The aarch64 hang was
misdiagnosed -- root-caused via `strace` as `DEBUGINFOD_URLS` (set by
Ubuntu's default profile), not a host/arch incompatibility. Fixed at the
image level in this tree too; lldb is a working "free alternative" again,
exactly as this entry originally said. See "Debugging: lldb hang was
DEBUGINFOD_URLS, not host/arch" below. This fix is *also* unverified on
x86_64 specifically -- same caveat as the morning update, just resolved
in the opposite direction.

---

## Debugging: lldb-server hangs on the aarch64 build host; gdb becomes the sole default for c/c++/rust here too

**Date:** 2026-07-20
**Status:** Superseded, same day — see "Debugging: lldb hang was
DEBUGINFOD_URLS, not host/arch" below. Every empirical test recorded
here (all performed on the aarch64 tree; this x86_64 entry was always a
preemptive, unverified mirror) was real and reproduced correctly; the
conclusion drawn from them (a fundamental, host/arch-level lldb-server
incompatibility) was wrong. The privilege-level testing correctly ruled
out capabilities/seccomp/SELinux as the cause -- it just didn't occur to
check environment variables next, which is where the actual answer was.
**Related issue:** Supersedes "Rust debugging: lldb over gdb" above;
revises "C debugging: keep gdb as primary, lldb available as a free
alternative" above.

**Decision:** Route c-mode/c++-mode/rust-mode/rust-ts-mode/rustic-mode
through dape's `gdb` config exclusively. Clear `lldb-dap`/`lldb-vscode`'s
`modes` list entirely (empty -- not offered in `SPC d d`'s completion for
any mode here) rather than uninstalling the `lldb` apt package, which
stays.

**Rationale:** Empirically confirmed on the aarch64 (26.04/M2) build --
this x86_64 (24.04) tree has NOT been independently tested; the same fix
is applied here preemptively, on the assumption that a hang this deep
(reproduces under every container privilege level, including
`--privileged`) is unlikely to be aarch64-specific rather than an
lldb-server issue in general. That assumption is unverified. If lldb
turns out to work fine on x86_64, this entry should be revised to keep
lldb available here even if aarch64 stays gdb-only.
- `lldb` (raw CLI and dape's DAP-mode adapter both) hangs indefinitely
  trying to launch any compiled binary on the aarch64 host -- tested
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
  exact same (aarch64) binaries. It hits the same underlying
  `personality()` ASLR-disable restriction lldb does in the container's
  default (no extra capabilities) config, but treats it as a non-fatal
  warning and proceeds anyway rather than aborting the launch.
- Verified live end-to-end on the aarch64 build via the actual `SPC d d`
  -> dape -> gdb DAP flow (not just raw CLI): breakpoint on `c.inc();`
  in the Rust flight-test, launch, correct stop at `flight_test::main` /
  `src/main.rs:17`, correct populated locals (`message "Hello"`, `c`
  present). Not yet repeated on this x86_64 tree.
- Keeping `lldb` installed rather than removing it: negligible image
  size cost, and aarch64 container support for lldb-server may mature
  later. If the hang gets root-caused and fixed (or turns out not to
  reproduce on x86_64 at all), re-adding
  rust-mode/rustic-mode/c-mode/c++-mode to `lldb-dap`'s `modes` in
  dape-config.el is a one-line revert.

**How it works:** see `dape-config.el` (extracted out of `config.el` as
its own file -- this is genuinely cross-language, not specific to any
one `:lang` module; also where the `:program` "a.out" fix lives).

**Revisit if:** the lldb-server hang gets root-caused and fixed, either
upstream or via a container-level workaround discovered here; or this
x86_64 tree gets independently tested and lldb turns out to work fine
here, in which case this entry should be split so x86_64 keeps lldb
available while aarch64 stays gdb-only.

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
default `modes` lists. The `:program` "a.out" fix from two entries back
stays as-is -- always correct, unrelated to either of these.

**Rationale, cause 1 (the hang):** Found and fixed on the aarch64 tree.
`strace -f` on a hanging `lldb -b -o run -o quit` showed no `ptrace`/
`personality`/`fork` call anywhere near the hang -- lldb was still inside
`target create`, stuck in a socket read/poll loop on a TLS connection to
`debuginfod.ubuntu.com`, which Ubuntu's `/etc/profile.d/debuginfod.sh`
points every login shell at by default. gdb prompts and auto-declines
non-interactively; lldb has no equivalent gate and just hangs.
`DEBUGINFOD_URLS=""` turned a hang into a 0.2-second clean launch.

**Rationale, cause 2 (`personality set failed: Operation not
permitted`):** Also found on aarch64, the hard way -- clearing
`DEBUGINFOD_URLS` alone was not sufficient; a rebuild tested against the
actual, unmodified `run.sh` (zero extra capabilities) hit this exact
error again, the very first one from this whole investigation. Same
underlying restriction gdb hits too (a non-fatal warning there): this
container's default seccomp profile denies the `personality()` syscall
lldb-dap's launch handler calls to disable ASLR before running the
debuggee. `~/.lldbinit` and an `initCommands` launch argument both run
too late to matter -- lldb-dap's ASLR-disable happens inside its own
launch-request handling, before either fires. `:disableASLR nil` is
lldb-dap's own dedicated DAP launch argument for exactly this. Setting it
skips the syscall entirely -- no capability, no seccomp override, no
`run.sh` change of any kind.

Full verification (raw CLI, live daemon restart, and the actual `SPC d d`
-> dape -> lldb-dap DAP flow with a correct breakpoint stop and
backtrace, all in the default `run.sh`-equivalent container with zero
extra privileges) was done on aarch64; see that tree's DECISIONLOG.md
entry of the same title for the complete account.

This x86_64 tree's `lldb-20`/symlink setup (see the "One real divergence"
note in BUILDLOG.md) is a different lldb build than aarch64's plain
`lldb` package, but both fixes here are generic (an env var, and a DAP
launch argument every lldb-dap build should support) -- applied on the
same reasoning as the rest of this debugging saga's x86_64 mirror:
preemptive, not independently verified on this tree yet.

**Revisit if:** debuginfod support for system-library symbols becomes
something this image actually wants (see aarch64 entry for the same
note); ASLR-enabled debugging becomes actively wanted (rare); or this
x86_64 tree gets independently tested and the picture turns out to differ
(e.g. if `lldb-20`'s build handles either of these differently than the
plain `lldb` package does).

---

## lldb-dap ignores every breakpoint: a real dape race condition, fixed with `:stopOnEntry`

**Date:** 2026-07-20
**Status:** Active

**Decision:** Add `:stopOnEntry t` to `lldb-dap`/`lldb-vscode`'s config in
`dape-config.el`. `defer-launch-attach` stays at its default (unset).

**Rationale:** Found and fixed entirely on the aarch64 tree; see that
tree's DECISIONLOG.md entry of the same title for the full account
(live JSON-RPC tracing via temporary advice on `jsonrpc-connection-send`,
reading `dape.el`'s actual source, ruling out `defer-launch-attach: t`
which deadlocks instead of fixing it, three separate live confirmations
including one after a full container restart). Short version: dape sends
`launch` unconditionally right after `initialize`'s response, on a path
independent of `setBreakpoints`/`configurationDone`, which only fire once
the adapter sends its own `initialized` event whenever it's ready -- a
genuine, unsynchronized race between the two dape sends. `:stopOnEntry`
sidesteps it by pausing the process at its very first instruction
regardless of breakpoints, giving the late `setBreakpoints` request time
to land before anything resumes.

**Cost:** every `SPC d d` now stops once at the process entry point
before reaching any of your own breakpoints -- one extra `SPC d c` needed
on every launch.

This x86_64 tree's fix is a straight mirror, same reasoning as the rest of
this debugging saga here: preemptive, not independently verified on this
tree.

**Revisit if:** this gets confirmed/reported upstream (`svaante/dape`)
and fixed there, at which point `:stopOnEntry` could potentially come
back out; a cleaner workaround is found that doesn't require the extra
`SPC d c`; or this x86_64 tree gets independently tested and the picture
turns out to differ.

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

## Fish and Assembly upgraded to full LSP; Perl kept deliberately syntax-only

**Date:** 2026-07-22
**Status:** Active

**Decision:** Of ROADMAP's original "syntax-only batch" (Fish,
Assembly, Perl), Fish and Assembly both got full LSP support
(`fish-lsp`, `asm-lsp`) instead of the originally-scoped plain syntax
highlighting. Perl stayed syntax-only on purpose. Source-mirrored from
the aarch64 tree; this tree's own image not yet rebuilt/tested this
session (deferred on purpose).

**Rationale:** Research surfaced real, actively-maintained language
servers for both Fish and Assembly that this project's own tooling
(`lsp-mode`) could reach with comparatively little added surface --
`asm-lsp` even ships a built-in `lsp-mode` client already, needing only
a forced `require`, no manual client registration. Given that low
marginal cost, upgrading both was a straightforward call. Perl was the
opposite: not a technical gap but an explicit product decision -- "I
hate Perl, code in it is usually a mess, I want to discourage Perl
use." Kept as-is: `perl` already ships as a transitive apt dependency
of something else in the image, and `perl-mode` + its `.pl`/`.pm`
mapping both ship built into Emacs core, so "syntax-only" here needed
zero code changes at all, not even an explicit apt install.

**Per-tree Dockerfile divergence for asm-lsp, not an oversight:** this
x86_64 tree has a real prebuilt Linux `asm-lsp` binary
(`asm-lsp-x86_64-unknown-linux-gnu.tar.gz`), so it uses the prebuilt-
tarball pattern (matching ruff/stylua), unlike the aarch64 tree (no
Linux/aarch64 release exists there, so it builds via `cargo install`,
needing `pkg-config`/`libssl-dev` added for `openssl-sys`). Two
different install mechanisms for the same tool, in the two trees, on
purpose.

**A process lesson, not just a product one:** two of the three
version-check tests written for this batch were wrong on first pass
(`asm-lsp --version` isn't a valid invocation -- it's a clap subcommand
CLI, needing `asm-lsp version` instead) and the LSP-connection test for
Assembly failed *consistently* in the full suite while passing in
isolation on the aarch64 tree -- root-caused to `go-mode.el`'s own
`magic-mode-alist` predicate (`go--is-go-asm`) silently hijacking `.s`
files into `go-asm-mode` whenever the same directory holds a `.go`
file, which this project's own Go fixture (`test.go`) does. Prompted
directly: "let's not have failing tests failing for cosmetic reasons,
fix the tests so that they aren't vulnerable to the same kind of
cosmetic quirks in the future" -- applied to two *other*, longer-
standing pre-existing failures too (`vcpkg` version string, `.h` file
mode), both traced to the same underlying class of bug (a shared flat
fixture directory where one language's mode-detection heuristic gets
confused by another language's sibling files), not random flakiness.
See the aarch64 tree's BUILDLOG.md for the full root-cause trail on
all four.

**Revisit if:** Perl's "discourage use" framing changes (e.g. if a
legacy Perl codebase actually needs to be worked on inside this IDE),
or this tree's own image gets rebuilt/smoketested and something here
doesn't hold on x86_64 the way it did on aarch64.

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

