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
