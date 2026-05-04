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
