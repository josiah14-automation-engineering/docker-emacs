# Mercury IDE Build Log
## Emacs 30.2 / Ubuntu 24.04 / x86_64

---

### Why compile Mercury from source rather than use the apt package?

Three reasons:

**1. Version currency.** Mercury is a niche academic language with infrequent Debian/Ubuntu packaging updates. The version in the Ubuntu 24.04 repos lags significantly behind the current stable release. Compiling from the upstream tarball ensures we're on the latest stable toolchain.

**2. CPU-specific optimization.** The images in this repo are compiled for a known target (Skylake). Passing `CFLAGS="-O2 -march=skylake -mtune=skylake"` at configure time lets `mmc` generate and link code tuned for that microarchitecture. The apt package is compiled for a generic x86-64 baseline.

**3. Grade selection.** Mercury's compiler produces different binaries depending on the *grade* — a configuration string that selects the GC strategy, parallelism model, threading model, and backend. Grades are essentially distinct ABIs; a library compiled in one grade cannot link against code compiled in another. The apt package ships only the default grade. We need three:

- `asm_fast.gc.par.stseg` — default runtime grade for normal execution
- `asm_fast.gc.par.stseg.debug` — enables `mdb`, Mercury's source-level debugger
- `asm_fast.gc.par.stseg.profdeep` — deep call-graph profiling via `mdprof`

Each grade requires the Mercury standard library to be compiled separately, which multiplies build time — but it's a one-time cost baked into the image.

---

### 2026-05-03

#### Ubuntu 24.04 package name changes

Migrating from a 22.04-era package list, several packages have changed names or been removed in 24.04:

- `ttf-dejavu` — removed; `fonts-dejavu-core` covers it and was already in the list
- `libtiff5` → `libtiff6`
- `libncurses5` — removed in 24.04; `libncurses6` covers it
- `libtinfo5` — removed in 24.04; `libtinfo6` covers it
- `libasound2` → `libasound2t64` (Ubuntu 24.04 64-bit time_t ABI transition)
- `libglib2.0-0` → `libglib2.0-0t64` (same transition)
- `gtk+3.0` — this is a source package name, not an installable binary package; correct name is `libgtk-3-0`
- `libffi8ubuntu1` — 22.04-specific package name; removed, `libffi-dev` covers the dependency

The `t64` suffix appears on packages whose ABI changed due to the 64-bit `time_t` transition Ubuntu introduced in 24.04. Not all packages were affected — `libgpm2`, `libgif7`, `libm17n-0` and others retained their original names.

#### Missing library at runtime: librsvg-2.so.2

Emacs failed to launch with:
```
emacs: error while loading shared libraries: librsvg-2.so.2: cannot open shared object file
```

This is the SVG rendering library. It wasn't in the package list carried over from the Python IDE scaffold. Fix: add `librsvg2-2`.

#### userdel cascades into group deletion

The Dockerfile deletes the default `ubuntu` user (UID/GID 1000) to avoid conflicts with the host user, then recreates a user matching the host UID/GID. Adding `-g ${USER_GID}` to `useradd` to properly assign the group exposed a subtle issue:

```
useradd: group '1000' does not exist
```

`userdel` removes not just the user but also its primary group. So by the time `useradd -g ${USER_GID}` runs, group 1000 is gone. Fix: add `groupadd -g ${USER_GID} ${USERNAME}` between `userdel` and `useradd`.

Also: `userdel --remove` attempts to delete the user's mail spool (`/var/mail/ubuntu`), which doesn't exist in a minimal base image. Dropped the `--remove` flag — there's no home directory or mail spool worth cleaning up in a fresh base image, and removing it eliminated the spurious warning without suppressing stderr.

#### AT-SPI accessibility bus warning

On first launch:
```
(emacs:1): dbind-WARNING **: Couldn't connect to accessibility bus: Failed to connect to socket /run/user/1000/at-spi/bus_1: No such file or directory
```

Non-fatal — Emacs runs fine. The AT-SPI accessibility bus simply isn't available in a container environment. Fix: set `ENV NO_AT_BRIDGE=1` in the Dockerfile to prevent the connection attempt.

#### Mercury toolchain build — non-obvious flags

A few things about Mercury's build system that aren't obvious from the configure help output and required digging into the upstream documentation:

**`--enable-libgrades` takes a comma-separated list.** The flag for building additional grades alongside the default is `--enable-libgrades`, and it expects grades separated by commas, not spaces:
```
--enable-libgrades=asm_fast.gc.par.stseg.debug,asm_fast.gc.par.stseg.profdeep
```

**`--with-default-grade` — initial assumption (later corrected).** Initial assumption was that `asm_fast.gc.par.stseg` would be auto-selected as the default grade for x86_64 Linux and that the flag was unnecessary. This turned out to be wrong — see correction below.

**Mercury uses its own parallelism flag.** Mercury's build system does not honour the standard `make -jN` flag. Parallel builds require passing `PARALLEL=-jN` as a make variable instead:
```
make PARALLEL=-j$(nproc)
make PARALLEL=-j$(nproc) install
```

**Two-stage bootstrap required for a fast compiler.** Inspecting the configure output revealed:
```
using grade 'asm_fast.gc' as the default grade for applications
WARNING: Mercury compiler not yet installed —
    cannot use grade 'asm_fast.gc'.
    Using grade 'hlc.gc.pregen' to compile the compiler.
    After installation is complete, you may reinstall
    from scratch to have a faster compiler.
```
With no existing `mmc` available, stage 1 compiles Mercury's compiler itself using `hlc.gc.pregen` — a portable C grade that is significantly slower than the native assembly grade. The *programs* you compile are still correct, but `mmc` itself runs slower than it should. Mercury's own documentation notes the fix: after the first install, run `make realclean`, reconfigure, and rebuild. With `mmc` now on `PATH`, stage 2 produces a compiler built in the target grade. `make realclean` between stages is mandatory — Mercury explicitly warns that skipping it may result in a broken installation.

**`--with-default-grade` is required, not optional (correction).** The configure output showed:
```
using grade 'asm_fast.gc' as the default grade for applications
```
Without `--with-default-grade=asm_fast.gc.par.stseg`, configure auto-selects `asm_fast.gc` — the simpler grade without parallelism or stack segment support. Programs compiled without an explicit `--grade` flag would then run without parallel execution support. The flag must be set explicitly to make `asm_fast.gc.par.stseg` the default.

**readline missing from `mdb`.** The configure output showed:
```
checking readline/readline.h usability... no
```
Without readline, `mdb` (Mercury's interactive source-level debugger) has no line editing or command history in its REPL. Fix: add `libreadline-dev` to the apt list before the Mercury build step.

**`flex` and `bison` are required build dependencies.** Mercury's configure script requires both to generate its lexer and parser. Neither is pulled in by `build-essential` and neither is mentioned in the Mercury documentation. They fail sequentially — `flex` first, then `bison` after `flex` is added:
```
checking for flex... no
configure: error: You need flex to build Mercury
```
```
checking for bison... no
checking for byacc... no
configure: error: You need bison to build Mercury
```
Fix: add both `flex` and `bison` to the apt package list.

With `flex` and `bison` in place, configure completes successfully and the build proceeds to compiling the Mercury build tools from C sources. This is the slow part of stage 1 — `mmc` is being bootstrapped from pre-generated C using `hlc.gc.pregen` before the faster native-grade compiler can be produced in stage 2.

#### Build failure during profdeep grade installation — suspected OOM

Stage 1 compiled and installed successfully. The failure occurred during `make install` while building the `asm_fast.par.gc.profdeep.stseg` grade of the standard library (note: Mercury normalizes grade component ordering — our specified `asm_fast.gc.par.stseg.profdeep` becomes `asm_fast.par.gc.profdeep.stseg` internally):

```
mmc --compile-to-c --grade asm_fast.par.gc.profdeep.stseg ... set_ordlist > set_ordlist.err 2>&1
gmake[2]: *** [integer.c_date] Error 1
```

The actual compiler error was not visible — Mercury redirects per-module output to `.err` files during parallel builds, and those files are inside the build directory which is cleaned up on container failure.

**Reasoning for OOM as most likely cause:**

The evidence chain:
1. The failure occurred specifically during the `profdeep` grade, not the default grade or the debug grade. Both of those completed successfully. This rules out a general build system problem and points to something grade-specific.
2. Deep profiling is the most memory-intensive Mercury grade by a wide margin. It instruments every call site in every procedure to build a full call-graph, which causes the compiler to hold substantially more state per module than any other grade.
3. The failing module was `integer` — one of the largest and most complex modules in the Mercury standard library. Large modules amplify memory pressure.
4. The build was running `make PARALLEL=-j$(nproc)` during install, meaning multiple `mmc` processes were compiling profdeep modules simultaneously. Each of those processes carries the full profdeep memory overhead, and they all compete for the same pool.
5. Docker containers run under Linux cgroups. Even if the host has ample RAM, the container may have memory limits — or the combined per-process footprint of N parallel profdeep compilations simply exhausted available memory without hitting any explicit limit.

The combination of (largest grade) × (largest module) × (maximum parallelism) under (container memory constraints) is a classic OOM profile.

**Fix attempt 1: reduce install parallelism to `-j1`.** The theory was that N parallel profdeep compilations were collectively exhausting memory. Switching `make install` to `PARALLEL=-j1` eliminated all parallelism during the install phase, leaving only a single `mmc` process running at a time.

Result: same failure, same module (`integer`), same grade (`asm_fast.par.gc.profdeep.stseg`). This ruled out parallelism as the cause entirely.

**Revised diagnosis: single-process memory exhaustion.** With `-j1`, only one `mmc` process is running. It still fails compiling `integer` in profdeep grade. This means a *single* `mmc` invocation — one process, one thread — cannot compile Mercury's `integer` module in the profdeep grade on this machine. Mercury's `integer` module implements arbitrary-precision integers and has an exceptionally large call graph. Profdeep instruments every call site in every procedure, which for a module this complex can require gigabytes of RAM in a single compiler invocation. No parallelism adjustment can address that.

The alternative explanation is a bug in Mercury 22.01.8 with the profdeep grade on GCC 13 / Ubuntu 24.04, but single-process memory exhaustion is the more parsimonious explanation given what profdeep does.

**Before dropping profdeep, diagnose properly.** The actual compiler error is hidden — Mercury redirects per-module output to `.err` files during the build, and those files are inside the build directory which is inaccessible after container failure. The error output shown in Docker is only the make failure cascade, not the underlying `mmc` error.

The fix: catch install failures and print all non-empty `.err` files to stdout before re-raising the error, so the actual message appears in the Docker build log:
```sh
make PARALLEL=-j$(($(nproc) / 2)) install \
  || (find . -name "*.err" ! -empty -exec sh -c 'echo "=== $0 ==="; cat "$0"' {} \; ; exit 1)
```

Install parallelism set to `nproc / 2` as a middle ground. Profdeep reinstated pending the actual error message.

**Actual error revealed — Mercury compiler bug, not OOM:**
```
Uncaught Mercury exception:
Software Error: predicate `ll_backend.prog_rep.goal_to_goal_rep'/4:
    Unexpected: non-plain conjunction and declarative debugging
```

This is a bug in Mercury 22.01.8's deep profiling implementation. `ll_backend.prog_rep` is the compiler module responsible for instrumenting code for deep profiling. `goal_to_goal_rep/4` converts compiler goal representations into the form used for profiling — and it has no handling for parallel conjunctions (`&`). Mercury's `integer` module uses parallel conjunctions for performance, and the profdeep instrumentation path hits an internal assertion failure when it encounters one.

This is not an OOM, not a build configuration issue, and not fixable by adjusting parallelism or memory. It is a Mercury 22.01.8 compiler bug in the interaction between parallel conjunctions and deep profiling instrumentation.

**Resolution: drop profdeep definitively.** The `asm_fast.gc.par.stseg.profdeep` grade is removed from `--enable-libgrades`. The two remaining grades cover all practical use cases for a development environment. Revisit with a newer Mercury release that may have fixed the `goal_to_goal_rep` parallel conjunction handling.

A bug report will be filed with the Mercury project at https://bugs.mercurylang.org/ with the full reproduction details. See `TODO.md`.

#### make realclean fails post-install

Stage 1 installed successfully. `make realclean` then failed:
```
MMAKE_DIR=`pwd`/scripts scripts/mmake realclean
/bin/sh: 2: scripts/mmake: not found
make: *** [Makefile:65: realclean] Error 2
```

`make realclean` depends on `scripts/mmake`, Mercury's make wrapper, which is no longer present in the source tree after `make install` moves things around. Mercury's documentation says `make realclean` is required between stages, but it doesn't survive the install.

Fix: replace `make realclean` with removing and re-extracting the source directory from the tarball (which is still present at this point in the RUN step). A fresh extraction is a more reliable clean slate than `make realclean` anyway.

#### Mercury toolchain build: success

With the re-extraction fix in place, the full two-stage build completed successfully. Both grades installed:
- `asm_fast.gc.par.stseg` — default runtime grade
- `asm_fast.gc.par.stseg.debug` — debug grade with `mdb` support

The Mercury toolchain is now in the image.

**Thermal note for laptop builds.** The Mercury compile is a sustained, CPU-intensive workload. On an ORPY6 laptop, CPU temperature hit 76°C under load. Elevating the rear of the laptop for improved passive airflow brought it down to 61°C. If building locally on a laptop rather than a server or CI runner, give your machine some airflow.

**sha512 file format ambiguity.** The upstream `.sha512` file may contain either just the hash or a full `hash  filename` line depending on the release. To handle both formats robustly, the hash field is extracted with `awk '{print $1}'` before constructing the input for `sha512sum -c`. The build fails loudly before extraction if the tarball is corrupt or tampered with.

#### Doom Emacs installation

With the Mercury toolchain confirmed working, the Doom Emacs installation layer was uncommented. Font installation (Powerline, Source Code Pro) and the Doom clone/install/sync steps are active. Custom config files (`config.el`, `init.el`, `packages.el`) remain commented out for now — validating the base Doom layer first before layering in Mercury-specific configuration.

The Doom clone URL was updated to use the `DOOM_REPO` ARG already defined in the Dockerfile rather than the hardcoded `hlissner/doom-emacs` URL (the old repo location). Pinned to the latest Doom commit at time of build: `4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57`.

#### doom install --fonts removed in latest Doom

Updating to the latest Doom commit exposed a breaking change: `--fonts` is no longer a valid flag for `doom install`. The flag was silently dropped from the CLI at some point. Fix: remove `--fonts` from the install command. Font installation is handled by the separate Powerline/Source Code Pro RUN step earlier in the Dockerfile, so nothing is lost.

This is exactly why Doom commits are pinned rather than tracking `master`. Doom does not use versioned releases, so breaking changes arrive silently with no changelog entry to catch them and no tagged version to revert to. Pinning to a specific commit hash makes the image reproducible and gives a deliberate upgrade path — update the hash, rebuild, fix whatever broke, document it. Staying on `master` would make it impossible to know when something broke or how to get back to a working state.

#### Doom Emacs layer: success

The Doom Emacs layer built and runs correctly. Startup is snappy, syntax highlighting works (confirmed with bash). Nerd Fonts required running `doom fonts install` manually inside a running container, then committing the container state back to the image with `docker commit`. This is a practical workaround — worth considering whether to bake `doom fonts install` directly into the Dockerfile as a RUN step so the fonts are part of the image build rather than a post-build manual step.

#### Base config files incorporated: success

`config.el`, `init.el`, and `packages.el` were uncommented in the Dockerfile and pulled into the image without issues. The `doom env --help` bug (which would have printed help text instead of generating the env file) was fixed to `doom env` at this point. Doom loads 213 packages across 59 modules in approximately 0.75 seconds — startup is fast.

---

### 2026-05-04

#### Dev image: source tree removed after install

After `make install` completes, the full Emacs source tree in `/opt/emacs` was left in the image — the clone, all generated C files, and the build artifacts. The multi-stage build only copies `/usr/local` into the IDE image, but the dev image itself is pushed independently and was carrying several hundred MB of dead weight. Fix: append `&& rm -rf /opt/emacs` to the end of the build RUN step. The cleanup runs in the same layer as the install, so the source never lands in the image.

#### Dev image: valgrind removed from build dependencies

`valgrind` was in the apt install list with no justification — nothing in the Emacs build or the dev image's purpose requires a memory debugger. Removed.

#### Dev image: xwidgets support attempted — blocked by WebKit version ceiling

`libwebkit2gtk-4.1-dev` was already installed as a build dependency but `--with-xwidgets` was absent from the configure flags. Added `--with-xwidgets` to attempt enabling Emacs's embedded browser widget. Build failed at configure:

```
checking for webkit2gtk-4.1 >= 2.12 webkit2gtk-4.1 < 2.41.92... no
checking for webkit2gtk-4.0 >= 2.12 webkit2gtk-4.0 < 2.41.92... no
configure: error: xwidgets requested but WebKitGTK+ or WebKit framework not found.
```

Emacs 30.2's xwidgets configure check enforces an upper bound of `< 2.41.92`. Ubuntu 24.04 ships `libwebkit2gtk-4.1` at version 2.44.x, which exceeds that ceiling. The check is a deliberate API compatibility guard — not a missing package — so there is no install-side workaround. Patching the configure script is possible but fragile and not worth the maintenance cost.

Resolution: reverted `--with-xwidgets`. `libwebkit2gtk-4.1-dev` remains in the apt list as a build dependency since it may still satisfy other configure probes. Xwidgets support is a candidate to revisit when upgrading to an Emacs release that has updated its WebKit version bounds.

#### IDE image: doom fonts install baked into the build

The previous workaround for Nerd Font installation — running `doom fonts install` interactively inside a running container and committing the result with `docker commit` — has been replaced with a proper build step. `doom fonts install` runs through the Doom CLI in batch mode and requires no display, so it works cleanly as a RUN step.

The call was appended to the end of the existing doom clone/install/sync RUN step. Grouping it there means fonts re-install automatically whenever the Doom commit pin is bumped — the right behavior, since the set of fonts Doom installs is tied to the Doom version.

The downloaded Nerd Font packages should be inspected after the next successful build to determine whether the earlier Powerline and Source Code Pro installation steps remain necessary or can be consolidated.

#### IDE image: DOOM_COMMIT ARG replaces DOOM_REF

The Dockerfile previously declared `ARG DOOM_REF=master` but never used it — the clone step always did `git reset --hard` to a hardcoded commit hash regardless of the ARG value. This was misleading: reading the ARG block implied the Doom version was configurable via `DOOM_REF`, but the actual pinned commit was buried in the middle of a RUN step.

Fix: replaced `DOOM_REF=master` with `DOOM_COMMIT=4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57` and updated the reset to `git reset --hard "${DOOM_COMMIT}"`. The pin is now visible at the top of the file alongside the other version ARGs, and bumping the commit is a one-line change in a predictable location. The two orphaned hash comments above the RUN step were removed — they were tracking earlier candidate commits and are superseded by the ARG.

---

### 2026-05-05

#### IDE image: unnecessary -dev packages removed

Several `-dev` packages in the apt list had runtime counterparts already present and served no purpose in the final image. Removed:

- `libgmp-dev` — `libgmp10` was already in the list
- `libncurses-dev` — `libncurses6` and `libncursesw6` were already in the list
- `libwebp-dev` — `libwebp7` and `libwebpdemux2` were already in the list
- `zlib1g-dev` — `zlib1g` was already in the list

The remaining `-dev` packages (`libffi-dev`, `libicu-dev`, `libreadline-dev`, `libgccjit-13-dev`) are still needed: the first three are Mercury build-time dependencies that stay until Mercury is isolated into its own build stage, and `libgccjit-13-dev` is required for Emacs native compilation during `doom sync --aot`.

#### Build failure: libwebpdecoder.so.3 missing after libwebp-dev removal

Removing `libwebp-dev` caused the build to fail immediately when Emacs was first invoked:

```
emacs: error while loading shared libraries: libwebpdecoder.so.3: cannot open shared object file: No such file or directory
```

`libwebp-dev` had been pulling in `libwebpdecoder3` as a transitive dependency. `libwebp7` and `libwebpdemux2` together do not cover the decoder library — it is a separate package in Ubuntu 24.04. The Emacs binary links against all three: `libwebp.so.7`, `libwebpdemux.so.2`, and `libwebpdecoder.so.3`.

Fix: added `libwebpdecoder3` explicitly to the apt list.

#### doom fonts install does not exist at the pinned Doom commit

With the `libwebpdecoder3` fix in place, the build progressed through the full Mercury two-stage compile and into the Doom Emacs layer. `doom sync` completed successfully, but the final step failed:

```
Error: unrecognized command: doom fonts install

Similar commands:
  - (46%) doom install
```

The 2026-05-04 entry documenting `doom fonts install` as a working baked-in build step was incorrect. The conclusion that it "works cleanly as a RUN step" was based on running the command interactively inside a running container — it was never validated in a full image build from scratch. At the pinned Doom commit (`4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57`), `doom fonts install` is not a recognized CLI subcommand.

Doom's icon/Nerd Font installation is done from inside a running Emacs instance via `M-x all-the-icons-install-fonts`, not through the `doom` CLI. This is already documented in the README as a manual post-build step.

Fix: removed `doom fonts install` from the Dockerfile RUN step. Powerline and Source Code Pro fonts are still installed by the earlier wget/git step. The all-the-icons font installation remains a manual post-boot step (boot container, run `M-x all-the-icons-install-fonts`, `docker commit`).

#### IDE image: font installation pinned and verified

Two reproducibility gaps in the font installation step were closed:

**Powerline fonts** — the `git clone` had no commit pin, so the installed fonts could silently change between builds. Pinned to commit `a029626780dd4af32f15a3e708a5b00528c22f1d` (HEAD at time of writing) by adding `git checkout <commit>` after the clone.

**Source Code Pro** — the download piped directly from `wget` into `tar`, making integrity verification impossible. Restructured to download to a temp file first, verify sha512, then extract. Hash: `2c55c413bab7d51f252659c63ba65624653dd03c1c64f0c16ece6973e5ae9a821e3675e04bbace263ceeaf71875538197071018761e00351359c876d7ad89fd6`

The `variable-fonts` tag in the adobe-fonts/source-code-pro repo is treated as stable; if it is ever moved the sha512 check will catch it and fail the build loudly.

#### IDE image: three-stage build

The Dockerfile was refactored from a two-stage build (emacs-build + final) to a three-stage build (emacs-build + mercury-build + final). The Mercury two-stage bootstrap compile moves into a throw-away `mercury-build` stage; the final image receives only `/usr/local` from each build stage via `COPY --from`.

Mercury build dependencies (`build-essential`, `gcc`, `g++`, `flex`, `bison`, `autoconf`, `automake`, `libtool`, `pkg-config`, `libffi-dev`, `libgmp-dev`, `libicu-dev`, `libreadline-dev`) are now confined to the mercury-build stage and do not appear in the final image. The final image gains the Mercury runtime equivalents instead: `libffi8`, `libicu74`, `libreadline8`, with `libgmp10` already present.

The mercury-build stage is intentionally inline rather than a separate pre-built image. Unlike the Emacs dev image — which is shared across multiple IDE images — the Mercury build is consumed only by this Dockerfile. Keeping it inline also co-locates the build dependencies and the runtime dependencies in a single file, making the coupling between them explicit and harder to accidentally break when bumping the Mercury version.

Build succeeded with this structure.

#### IDE image: build success

With the above fixes in place the full image built successfully. The image contains:

- Emacs 30.2 compiled from source with native compilation, tree-sitter, Cairo/HarfBuzz, and the full Skylake-tuned flag set — copied from the dev image
- Mercury 22.01.8 compiled from source in two bootstrap stages; both grades installed: `asm_fast.gc.par.stseg` (default) and `asm_fast.gc.par.stseg.debug`
- Doom Emacs at commit `4e0dbb9dc5a3986303295cd7ce5e9faf113c4a57`, AOT-compiled, with custom `config.el`, `init.el`, and `packages.el` applied
- Powerline and Source Code Pro fonts installed at build time

Remaining manual post-boot steps before the image is production-ready (per README):
1. Two unicode mapping passes (let each complete before proceeding)
2. `M-x all-the-icons-install-fonts` to install Nerd Fonts
3. `docker commit` the result

---

### 2026-05-05 (continued)

#### Mercury mode and flycheck wiring

Added `mercury.el` — a separate config file loaded via `(load! "mercury")` in `config.el`. Using a separate file rather than inlining into `config.el` because the Mercury-specific setup has enough distinct concerns (mode, checker definition, hook) to warrant isolation.

**Major mode selection — why not Mercury's own `mercury.el`?**

Mercury's source distribution ships Emacs support in `extras/emacs/mercury.el`. However, that directory is not installed by `make install` — it lives only in the source tree. Since the Dockerfile cleans up the source tree after both compile stages (`rm -rf mercury-srcdist-${MERCURY_VERSION}`), Mercury's own `mercury.el` is not present in the image. Options considered:

1. **Mercury's `extras/emacs/mercury.el`** — not available post-cleanup; would require either skipping the rm or separately extracting and installing the elisp file. Not worth the complexity.
2. **`prolog-mode` with Mercury dialect** — Emacs ships `prolog-mode` which has a `(setq prolog-system 'mercury)` dialect setting. Mercury's syntax is Prolog-derived and prolog-mode's highlighting mostly applies. Rejected because it's a poor fit: Mercury has distinct syntax (type declarations, mode declarations, determinism annotations, `:-` vs `-->` vs `==>`) that prolog-mode doesn't know about.
3. **`metal-mercury-mode`** (GitHub: `ahungry/metal-mercury-mode`) — a dedicated Mercury major mode, installable via straight.el recipe. Selected.

**Flycheck checker — why not write one from scratch?**

Initial plan was to write a custom `flycheck-define-checker` for `mmc`. Abandoned after finding `flycheck-mercury` on MELPA (GitHub: `flycheck/flycheck-mercury`). It defines checker `mercury-mmc` with a custom error parser (`flycheck-mmc-error-parser`) that processes mmc output line-by-line rather than using regex patterns — this is the right approach because mmc's error format doesn't have a fixed column field and severity classification requires context across lines.

**Mode-name mismatch — not actually an issue.** Reading `flycheck-mercury`'s source confirmed that its `:modes` list explicitly includes `mercury-mode`, `metal-mercury-mode`, and `prolog-mode`. Flycheck's auto-selection works without any explicit `setq-local flycheck-checker`. Checker name confirmed as `mercury-mmc`.

**mmc invocation:** `mmc -e --infer-all <source>`. `-e` means check only — no `.c`/`.o` side effects. `--infer-all` allows the compiler to infer types, modes, and determinism rather than requiring full annotations, which matters for learning code that won't always have complete declarations.

**No LSP.** The CLAUDE.md note (and earlier decision) stands: no LSP server exists for Mercury with reliable support. `dumb-jump` (provided by the `lookup` module already in `init.el`) handles go-to-definition via grep. Flycheck with `mmc` handles error feedback.

**Files changed:**
- `mercury.el` — new file (mode, flycheck integration, hook)
- `packages.el` — added `flycheck-mercury` (MELPA) and `metal-mercury-mode` (GitHub recipe)
- `config.el` — added `(load! "mercury")`
- `Dockerfile` — added `COPY` for `mercury.el` alongside the other doom config files

---

#### straight.el package lockfile

Captured the exact commit hash of every installed package (420 packages) in `straight-versions.el`, baked into the image via Dockerfile COPY.

**Path correction from TODO.** The TODO assumed straight.el lived at `~/.config/emacs/straight/`. It actually lives at `~/.config/emacs/.local/straight/`. The correct COPY destination is therefore:
```
/home/${USERNAME}/.config/emacs/.local/straight/versions/default.el
```

**`straight-freeze-versions` was unusable.** Running `M-x straight-freeze-versions` inside a running container produced "Caches are outdated, reload init-file?" → "Caches are still outdated; something is seriously wrong." This is a straight.el/Doom cache mismatch that occurs when packages were installed during a Docker build (not a normal interactive session) and straight's internal state wasn't fully initialized for interactive use.

**Lockfile generated directly from repos.** Since straight's repos are plain git clones at `~/.config/emacs/.local/straight/repos/`, the lockfile was generated by walking each repo and extracting its current HEAD commit:

```bash
(echo '('; for d in ~/.config/emacs/.local/straight/repos/*/; do
  name=$(basename "$d")
  hash=$(git -C "$d" rev-parse HEAD 2>/dev/null)
  [ -n "$hash" ] && echo "  (\"$name\" . \"$hash\")"
done; echo ')') > /tmp/default.el
```

The output is valid straight.el alist format — `straight-freeze-versions` would have written the same structure. The file was copied out of the container with `docker cp` and committed as `straight-versions.el`.

**Layer ordering.** The COPY lands before the final `doom sync`, so straight.el has the lockfile in place during that sync run. Docker creates the `versions/` directory automatically — it didn't exist in the running container and doesn't need to be pre-created.

---

#### Pop!_OS launcher integration

The IDE is accessible from the GNOME application launcher as "Logic Languages IDE". Named broadly to leave room for Prolog and other logic languages in the same container rather than creating a separate image per language.

**Files (not committed — contain personal system paths; keep in `host/` which is gitignored):**

- `host/logic-languages-ide` — launch script
- `host/logic-languages-ide.desktop` — desktop entry

**Install locations (symlinked from `host/`):**

```
~/.local/bin/logic-languages-ide
~/.local/share/applications/logic-languages-ide.desktop
```

**Launch script:**

```bash
#!/usr/bin/env bash
set -euo pipefail

exec docker run --rm \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /home/josiah/Development:/home/josiah/Development \
  --name doom-mercury-ide \
  --network=host \
  josiah14/mercury-doom-emacs-ide:30.2-skylake-ubuntu-24.04
```

`exec` replaces the shell with the docker process rather than leaving a parent shell running. `--network=host` is needed for X11 display access. `--rm` keeps containers clean on exit.

**Desktop entry:**

```ini
[Desktop Entry]
Name=Logic Languages IDE
Comment=Mercury and Prolog development environment (Doom Emacs 30.2)
Exec=/home/josiah/.local/bin/logic-languages-ide
Icon=emacs
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=false
```

`StartupNotify=false` suppresses the GNOME spinning cursor — the container takes a moment to start and GNOME would otherwise show the app as "not responding".

**To register with GNOME after installing the `.desktop` file:**

```bash
update-desktop-database ~/.local/share/applications/
```

**To set up on a new machine:** recreate `host/` with the above contents, `chmod +x` the script, symlink both files, run `update-desktop-database`.

---

### 2026-05-06

#### Post-completion review: external feedback and targeted hardening

With the mercury-ide image working end-to-end, the Dockerfile and supporting files were reviewed against a set of external critique. Items actioned, in order:

**1. Doom binary PATH bug (fixed)**

The final image had:
```dockerfile
ENV PATH="/home/${USERNAME}/.emacs.d/bin:/home/${USERNAME}/.local/bin:${PATH}"
```
But Doom is cloned to `~/.config/emacs`, so `~/.emacs.d/bin` does not exist. All `doom` invocations in the Dockerfile use full paths, so the build succeeded — but `doom` was unreachable from the container shell at runtime. Fixed to `~/.config/emacs/bin`.

**2. Mercury tarball SHA512 hardened**

The build previously fetched both the tarball and its `.sha512` file from the same release host (`dl.mercurylang.org`). A compromised host could serve matching tampered files, and the `sha512sum` check would still pass. Added `ARG MERCURY_SHA512` with the known hash baked in; the `.sha512` fetch was removed. The build now verifies the tarball against a value committed to the repository rather than one fetched at build time.

**3. CPU tuning parameterized — scope catch by Josiah**

`-march=skylake -mtune=skylake` was hardcoded in the Mercury configure `CFLAGS`. The initial fix parametrized those flags in `mercury-ide/Dockerfile` using `ARG MARCH=skylake` / `ARG MTUNE=skylake` and updated `mercury-ide/build.sh` to pass them through with the image tag reflecting the chosen tuning.

Josiah noted that the same hardcoded flags existed in the dev image Dockerfile as well, and that both build scripts needed corresponding updates — neither of which had been addressed. This was a correct and substantive catch: the dev image is the base layer for the entire 30.2 IDE stack, so leaving its CFLAGS hardcoded would have made the parameterization incomplete and the dev/IDE images inconsistent. The fix was extended to `30.2/ubuntu/24.04/x86_64/dev/Dockerfile` and `dev/build.sh`, with `MARCH`/`MTUNE` as shell variables in both build scripts defaulting to `skylake` and overrideable via environment.

**4. Identity templating for public sharing — Josiah pushed scope**

With the CPU tuning work done, Josiah directed that `FULLNAME` and `EMAIL` be removed from `mercury-ide/build.sh` where they were hardcoded as literal strings, and that `config.el` be confirmed clean of personal data. `config.el` had:
```elisp
(setq user-full-name "<full-name>"
      user-mail-address "<email-address>")
```
The Dockerfile had always contained a `sed` substitution step for `<full-name>` and `<email-address>` placeholders, but `config.el` used real values, making the `sed` a no-op. The decision to open-source this repo activated the mechanism properly: `config.el` now uses the placeholders, `build.sh` reads `FULLNAME` and `EMAIL` from the environment and fails fast if either is unset, and `CLAUDE.md` was updated to document the live injection path.
