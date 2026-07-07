# Mercury IDE Build Log
## Emacs 30.2 / Ubuntu 26.04 / aarch64 (Apple M2)

---

### 2026-07-06

#### Starting point: ported from 24.04/x86_64, package names re-verified against ubuntu:26.04 arm64

This image was modeled on `30.2/ubuntu/24.04/x86_64/mercury-ide`, following the same
three-stage build (`emacs-build` copy, inline `mercury-build`, final image) and the
same Doom config files (`config.el`, `init.el`, `keybindings.el`, `mercury.el`,
`nix-keybindings.el`, `packages.el`, `straight-versions.el` — all byte-identical to
the x86_64 reference; none of them reference OS/arch-specific paths or package
names, so no changes were needed there).

Package names were re-verified from scratch against `ubuntu:26.04` arm64 (Ubuntu
26.04 LTS "Resolute Raccoon") rather than assumed from the x86_64/24.04 list, since
two Ubuntu releases and an architecture separate them. Verified two ways:

1. `apt-cache show <pkg>` against a live `ubuntu:26.04` arm64 container for every
   package in the x86_64 list (note: `apt-cache show nonexistent-pkg` exits 0 with
   empty output — checking the exit code alone gives false positives; the check
   must grep for `^Package: <name>` in the output).
2. `ldd` against the *actual* compiled Emacs binary from
   `josiah14/emacs:30.2-m2-ubuntu-26.04-dev` (already built), installed into a
   throwaway `ubuntu:26.04` container with the candidate runtime package list, to
   confirm zero `"not found"` entries. This is strictly more reliable than name
   matching alone, since a renamed package can still resolve to the wrong SONAME
   (see the `libgccjit` case below) without `apt-get install` ever failing.

**Renames found (26.04 arm64 vs. 24.04 x86_64):**

| 24.04 x86_64 | 26.04 aarch64 | Why |
|---|---|---|
| `libgnutls30` | `libgnutls30t64` | package renamed |
| `libgtk-3-0` | `libgtk-3-0t64` | package renamed |
| `libtree-sitter0` | `libtree-sitter0.25` | soname-versioned package name |
| `libxml2` | `libxml2-16` | soname-versioned package name (libxml2 2.12+ ABI break) |
| `libicu74` | `libicu78` | ICU version bump |
| `libreadline8` | `libreadline8t64` | package renamed |
| `libgccjit-13-dev` | `libgccjit-15-dev` | **not just a rename** — see below |

**The `libgccjit` case is not a simple rename.** Ubuntu 26.04 ships gcc-11 through
gcc-14 sharing one runtime package, `libgccjit0` (`libgccjit.so.0`), while gcc-15+
switched to per-version runtime packages: `libgccjit15` ships `libgccjit.so.15`,
`libgccjit16` ships `libgccjit.so.16`. `libgccjit-13-dev` still exists and installs
cleanly on 26.04 (`apt-cache show` finds it) — it just depends on the *wrong* shared
library. `gcc` defaults to gcc-15 on 26.04, and the dev image's Emacs was actually
built (`--with-native-compilation=aot`) against `libgccjit-15-dev`/`libgccjit.so.15`
(confirmed via `ldd /usr/local/bin/emacs`, see below). Installing `libgccjit-13-dev`
in the final image would silently provide `libgccjit.so.0`, which does not satisfy
the `libgccjit.so.15` the Emacs binary actually needs — a link failure at native-comp
time, not an apt error. This is exactly the class of bug the `ldd`-against-the-real-
binary verification step exists to catch: `apt-get install` succeeding is not the
same as "the right package."

**`ldd /usr/local/bin/emacs` against the real dev-image binary — zero missing
libraries with the corrected list**, including several the x86_64 list's runtime
packages don't obviously cover on their own (`libsqlite3.so.0`, `libotf.so.1`,
`libstdc++.so.6`, `libpng16.so.16` via `libpng16-16t64`, `libX11.so.6` via
`libx11-6`): all resolved transitively through the existing package list's
dependency chains (`libgtk-3-0t64` pulls in most of the GTK/Pango/Cairo/X11 stack;
`libtiff6` pulls `libpng16-16t64`; etc.), so none needed to be added explicitly.
`libsqlite3.so.0` in particular is linked because both dev Dockerfiles
(24.04/x86_64 and 26.04/aarch64) include `libsqlite3-dev` as a build dependency,
which Emacs 30's configure auto-detects and enables (no explicit `--with-sqlite3`
flag exists to control this either way).

**`libsm6` was left in the apt list but is not actually linked.** `ldd` on the real
binary shows no `libSM.so.6` dependency: the 26.04/aarch64 dev image is built with
`--with-pgtk` (native Wayland GTK), unlike the x86_64/24.04 dev image, which doesn't
use pgtk and links plain X11/Xt. `libxaw7` and `libxcb-util1` are similarly present
in the apt list but not linked for the same reason (no Xaw/Xt toolkit in a pgtk
build). Left in for now rather than removed, since they're harmless and this
mirrors the x86_64 list; a future pass could drop them (same spirit as the x86_64
TODO.md's own "uncertain — remove and verify with a test build" section for
`libxaw7`/`libxcb-util1`/etc., which flagged this exact uncertainty for the x86_64
build without a definitive answer — the `--with-pgtk` difference gives an aarch64-
specific definitive answer that doesn't necessarily carry back to x86_64).

---

#### `ARG MCPU` build-arg scoping bug (found and fixed)

The Dockerfile declared:
```dockerfile
FROM josiah14/emacs:30.2-m2-ubuntu-26.04-dev AS emacs-build

ARG MCPU=apple-m2+crc+aes+sha3+fp16
```
`ARG MCPU` here comes *after* the first `FROM`, which makes it local to the
`emacs-build` stage only (which never uses it — that stage just copies a
pre-built image). The `mercury-build` stage's own `ARG MCPU` re-declaration had no
way to inherit a default from a stage-scoped ARG in a *different* stage. Docker's
scoping rules: an `ARG` before the first `FROM` is "global" and can be re-imported
into any stage via a bare `ARG NAME` (inheriting the global default); an `ARG`
declared after a `FROM` is local to that stage and does not propagate to later
stages at all, even under the same name.

Fixed by moving `ARG MCPU=apple-m2+crc+aes+sha3+fp16` above the first `FROM`, so it
is genuinely global and inherited correctly by `mercury-build`'s `ARG MCPU` line.
Matches the x86_64 reference's pattern (`ARG MARCH=skylake` / `ARG MTUNE=skylake`
declared before the first `FROM`, then bare `ARG MARCH` / `ARG MTUNE` re-imports in
the stage that uses them).

---

#### Grade set expanded to match mise's nixpkgs mercury derivation

Per direction: build the same grade set as
`~/Development/personal/mise/languages/mercury/compilers/22.01.8.nix`, so code
compiled in this Docker image and code compiled in a mise/nix-managed shell target
the same set of ABIs. That derivation's `preConfigure`:
```
configureFlags="--enable-deep-profiler=$out/lib/mercury/cgi-bin --with-default-grade=asm_fast.gc.stseg --enable-libgrades=asm_fast.par.gc.stseg,asm_fast.gc.stseg,asm_fast.gc.debug.stseg,asm_fast.gc.prof.stseg,asm_fast.gc.profdeep.stseg,asm_fast.gc.tr"
```

Adopted (dropping the redundant repeat of the default grade — `asm_fast.gc.stseg`
appears both as `--with-default-grade` and again in mise's `--enable-libgrades`
list; Mercury's configure de-dupes this automatically, confirmed by a standalone
`./configure` test showing "Configuring to install 6 grades" either way, so the
repeat is harmless but not necessary in a Dockerfile we control):

```
--with-default-grade=asm_fast.gc.stseg
--enable-libgrades=asm_fast.par.gc.stseg,asm_fast.gc.debug.stseg,asm_fast.gc.prof.stseg,asm_fast.gc.profdeep.stseg,asm_fast.gc.tr
--enable-deep-profiler=/usr/local/lib/mercury/cgi-bin
```

**This changes the default grade from parallel to sequential**, a real behavioral
difference from the x86_64/24.04 image (which defaults to `asm_fast.gc.par.stseg`).
Consequence: flycheck-mercury's bare `mmc` invocation (no `--grade` flag; see
`mercury.el`) now resolves to the same default grade a project built via mise/nix
would use — the two environments agree, which is the point of matching mise's
config in the first place.

**`--enable-deep-profiler=<dir>` requires the target directory to exist before
`configure` runs**, or configure fails with `... does not exist`. mise's derivation
does `mkdir -p $out/lib/mercury/cgi-bin` in its `preConfigure` hook for the same
reason; the Dockerfile does `mkdir -p /usr/local/lib/mercury/cgi-bin` before each of
the two `./configure` invocations (the directory survives the source-tree
reset-and-re-extract between stage 1 and stage 2, since only the source tree is
removed, not the install prefix — but the `mkdir -p` is repeated defensively before
each configure anyway, matching mise's per-configure hook).

**`libncurses-dev` and `texinfo`** were added to the mercury-build stage's apt list,
beyond the x86_64/24.04 build-dep list. mise's derivation depends on
`pkgs.readline` and `pkgs.ncurses` with the comment "required by mdb ... at link
time" — `libreadline-dev` was already present (needed since the x86_64 build), but
`libncurses-dev` was not. `texinfo` (providing `makeinfo`) fixes a configure
warning ("missing `makeinfo' or `info'... necessary ... for the help text in the
debugger") that would otherwise ship `mdb`/`mdprof` without embedded help text.

---

#### Whether `asm_fast.gc.profdeep.stseg` (no `.par`) hits the known Mercury 22.01.8 bug: pending build verification

The x86_64/24.04 image dropped `asm_fast.gc.par.stseg.profdeep` after hitting a
Mercury 22.01.8 compiler bug: the deep-profiling instrumentation
(`ll_backend.prog_rep.goal_to_goal_rep/4`) cannot handle the parallel conjunctions
(`&`) used by the `integer` stdlib module. That bug's own description ties it
specifically to profiling a *parallel* conjunction — the grade requested here,
`asm_fast.gc.profdeep.stseg`, has no `.par` component. mise's own working
derivation builds exactly this non-parallel profdeep grade, which is a strong
signal it doesn't hit the same failure, but this hasn't yet been independently
confirmed against this image's own build (in progress as of this writing — see the
"Build result" section below, filled in once the two-stage build completes).

---

#### GCC 15 build failure: `mercury_wrapper.c`/`mercury_trace_base.c` — `-Werror=discarded-qualifiers`

Stage 1 (`hlc.gc.pregen` bootstrap) failed compiling the Mercury runtime itself:
```
mercury_wrapper.c:2368:7: error: assignment discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
    s = strrchr(MR_progname, '/');
```
and the same class of error in `mercury_trace_base.c:278`. This is **not**
architecture-specific — it reproduces because Ubuntu 26.04's default `gcc` is
gcc-15, versus gcc-13 on Ubuntu 24.04 (the x86_64 image's compiler), and GCC's
built-in `strrchr`/`strchr`-family const-correctness checking has gotten stricter.
`MR_progname` is declared `const char *`; GCC's builtin prototype for `strrchr`
propagates constness from a const argument, so the return value is treated as
`const char *`, and assigning it to the non-const `char *s` triggers
`-Wdiscarded-qualifiers` — code that (with older GCC) apparently didn't trigger
this, or triggered only a non-fatal warning.

**Why this can't be fixed by downgrading the compiler.** The obvious-looking fix —
install `gcc-13` (matching Ubuntu 24.04, the known-working compiler) alongside the
default `gcc` in the mercury-build stage and point Mercury's configure at it — was
tried and rejected: `gcc-13` does not recognize `apple-m2` as a valid `-mcpu` value
at all (confirmed: `gcc-13 -mcpu=apple-m2+... conftest.c` → `cc1: error: unknown
value 'apple-m2+crc+aes+sha3+fp16' for '-mcpu'`, with a valid-values list that has
no `apple-*` entries). Apple Silicon `-mcpu` support is a newer-GCC-only feature.
Downgrading the compiler to dodge this bug would mean losing Apple M2 CPU tuning
for the Mercury toolchain entirely — not an acceptable trade for a CPU-tuned build.

**Why this isn't controllable through `CFLAGS=` the way a normal C project's would
be.** Mercury's `scripts/mgnuc` wrapper (auto-generated from `mgnuc.in` at
configure time) hardcodes its own warning-flags block for gcc
(`-Wall -Wwrite-strings -Wshadow -Wstrict-prototypes -Wmissing-prototypes
-Wno-unused -Wno-uninitialized -Wno-array-bounds ... -Werror ...`) when building in
high-level-C (`hlc.*`) grades — confirmed by wrapping `gcc` in a logging shim and
capturing the literal argv mgnuc invoked for `mercury_wrapper.c`. This `-Werror` is
unconditional for HLC grades, not gated behind any configure flag we control.

**The actual fix: `-Wno-error=discarded-qualifiers` in `CFLAGS`, relying on
argument order.** `scripts/Mmake.vars.in` defines
`ALL_MGNUCFLAGS = $(MGNUCFLAGS) $(EXTRA_MGNUCFLAGS) $(TARGET_MGNUCFLAGS) -- $(ALL_CFLAGS)`
— note the literal `--` before `$(ALL_CFLAGS)`. `mgnuc`'s own option-parsing loop
breaks out (stops interpreting `--xxx` meta-options) at the first `--` or first
unrecognized token, and everything after gets appended *verbatim, at the very end*
of the real `gcc` invocation — after mgnuc's own hardcoded `-Wall ... -Werror ...`
block. GCC processes `-W`-family flags in argument order, so a `-Wno-error=<name>`
appearing *after* an earlier bare `-Werror` correctly exempts just that one
diagnostic back to warning severity, without disabling `-Werror` for anything else.
Confirmed directly: capturing the real gcc invocation and re-running it by hand
with `-Wno-error=discarded-qualifiers` appended turned the build failure into a
plain warning (exit 0, object file produced).

One dead end on the way there, worth recording so it isn't retried: a bare
`-Wno-discarded-qualifiers` (suppressing the diagnostic itself, rather than just
its error promotion) was tried first, on the theory that a suppressed diagnostic
has nothing left for `-Werror` to escalate. It did not clear the error in a full
`make` run, for reasons not fully root-caused (a manual, hand-built `mgnuc`
invocation isn't a perfect stand-in for the real `make`-driven one — the working
fix was verified against the *actual* `make`-invoked command line, not a hand-rolled
approximation of it). `-Wno-error=discarded-qualifiers` is the confirmed-working
form; use that, not the bare `-Wno-discarded-qualifiers`.

Dockerfile CFLAGS became:
```
CFLAGS="-O2 -mcpu=${MCPU} -Wno-error=discarded-qualifiers"
```
applied to both configure invocations (stage 1 and stage 2).

---

#### `doom sync --gc`: verified NOT deprecated at the pinned commit

A report surfaced mid-session that `--gc` on `doom sync` is deprecated and needs to
run as a separate `doom gc` step. Checked directly against this image's actual pin
(`DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57`, same as the x86_64
reference): `lisp/cli/sync.el` at that commit defines `--gc` as a first-class,
fully-documented `sync` option ("Purge orphaned package repos & regraft them"), and
`doom sync --help` at that commit shows no deprecation notice. Went further and ran
the actual `doom install -! --aot` + `doom sync -! -u -j N --aot --gc` sequence
against the real dev-image Emacs — completed cleanly, `--gc` purged/regrafted
packages exactly as documented, no warnings.

Doom's *current* master branch (as of 2026-07-03,
`8e4fbbae048a9abe897bf1878cbd32732a6d41d7`) has in fact removed `lisp/cli/sync.el`
and `lisp/cli/gc.el` entirely — `git log --oneline --all -- lisp/cli/sync.el` shows
a `refactor(cli): move cli/*.el to bin/doom-*` commit reachable from some branch,
and master's `lisp/cli/` only has `autoloads.el`, `loaddefs.el`, `make/*`, and
`print.el` left. Doom has evidently undergone a larger CLI restructuring since this
image's pin. That's exactly why `CLAUDE.md` and this repo's convention pin Doom to a
specific commit rather than tracking master — and it's why this image keeps the
same pin as the x86_64 reference rather than bumping it. No change made; `--gc`
stays as-is, both `doom sync` invocations unchanged.

---

#### Build result: `CFLAGS`-based fix failed, real cause was `runtime/Mmakefile`'s own `MGNUCFLAGS`

The build with `CFLAGS="-O2 -mcpu=${MCPU} -Wno-error=discarded-qualifiers"` was run
in the background and had to be stopped early (ran out of time before leaving the
house). On resuming, the logged build output showed it had actually failed —
quickly, at the 28-second mark of the Mercury `RUN` step, not after hours. The
actual failing invocation:

```
../scripts/mgnuc --grade hlc.gc.pregen    --c-debug --no-ansi   --       -c mercury_trace_base.c -o mercury_trace_base.o
```

No CFLAGS-derived flags anywhere in that command line. Root cause: `runtime/Mmakefile`
builds the `runtime/` C library (needed before mmc even exists, for both bootstrap
stages) via its own `MGNUCFLAGS += --c-debug --no-ansi`, not the general `CFLAGS`
passed to `./configure`. The `Mmake.vars.in` mechanism the previous fix relied on
(`$(ALL_CFLAGS)` appended after `--` in the mgnuc invocation) is real, but only
applies to other build targets (grade-specific library/compiler compiles) — Mercury's
build system doesn't thread user `CFLAGS` through uniformly everywhere.

Verified in an isolated `ubuntu:26.04` container (fresh curl + extract + configure,
no Docker build needed) before touching the real Dockerfile:

- Reproduced the exact failure standalone: `mercury_trace_base.c` and
  `mercury_wrapper.c` both hit `-Werror=discarded-qualifiers` via `hlc.gc.pregen`.
- Confirmed `scripts/mgnuc`'s final invocation is
  `${CC} ${ALL_CC_OPTS} "$@" ${OVERRIDE_OPTS} ${ALL_LOCAL_C_INCL_DIRS}` —
  `OVERRIDE_OPTS` is appended last, after mgnuc's own hardcoded `-Werror` for
  `hlc.*` grades, and is used by every compile mgnuc performs regardless of which
  Mmakefile invoked it.
- Patched the *generated* `scripts/mgnuc` (not the `.in` template — regenerated
  fresh by each `./configure` call, so the patch must be reapplied after both stage
  1 and stage 2 configure invocations) to append
  `-Wno-error=discarded-qualifiers` to `OVERRIDE_OPTS` immediately before the one
  line that consumes it. Anchor had to be the full `set ${CC} ...
  ${ALL_LOCAL_C_INCL_DIRS}` line specifically — an earlier, unrelated `case $# in`
  block (default-grade argument injection) matches a naively shorter anchor and
  produces a harmless but sloppy duplicate insertion.
- Retested both previously-failing files standalone: both now compile with just a
  warning (`-Wdiscarded-qualifiers`, no longer promoted to error), exit 0, valid
  `.o` produced.

Dockerfile updated: dropped the non-functional `-Wno-error=discarded-qualifiers`
from `CFLAGS` (back to plain `CFLAGS="-O2 -mcpu=${MCPU}"`), added the `sed`-based
`scripts/mgnuc` patch as its own step after each `./configure`, before `make`.
Full six-grade build relaunched with this fix; result to follow.
