# TODO

## Refactor to three-stage build to eliminate Mercury build dependencies from final image

The mercury-ide Dockerfile currently installs Mercury's build-time apt dependencies (`build-essential`, `gcc`, `g++`, `flex`, `bison`, `libreadline-dev`, `autoconf`, `automake`, `libtool`, `libffi-dev`, `libicu-dev`, `pkg-config`, `libgccjit-13-dev`, `make`, etc.) in a layer that persists into the final image. Only the installed Mercury toolchain under `/usr/local` is actually needed at runtime.

The fix is a three-stage build mirroring the pattern already used for Emacs:

1. **Stage 1 — Emacs build** (`josiah14/emacs:30.2-skylake-ubuntu-24.04-dev`): already exists, unchanged.
2. **Stage 2 — Mercury build**: a throw-away layer that installs the Mercury build dependencies, compiles Mercury from source (both bootstrap stages), and installs to `/usr/local`.
3. **Stage 3 — Final image**: starts from `ubuntu:24.04`, copies `/usr/local` from both build stages via `COPY --from`, installs only runtime apt dependencies, then layers in Doom Emacs and config.

The runtime apt dependencies for Mercury are a subset of the build dependencies — primarily `libgmp10`, `libreadline8`, and `libgcc-s1`. Everything else (`flex`, `bison`, `build-essential`, etc.) is build-time only and can be dropped from the final image.

This mirrors exactly how the Emacs dev image already works and will produce a meaningfully smaller final image.

---

## Dev image: remove unused and misplaced apt packages

The following packages in the dev Dockerfile apt list have no role in building Emacs and should be removed:

**Certain removals:**
- `libwebkit2gtk-4.1-dev` — was installed for xwidgets support; xwidgets dropped after Ubuntu 24.04 WebKit version incompatibility. Now unused.
- `libseccomp-dev` — Linux syscall filtering library. Not referenced in any Emacs configure flag or build step.
- `libpthread-stubs0-dev` — provides pthread stub libraries for systems where pthread isn't in libc. On Ubuntu 24.04 with glibc, pthread is part of glibc and this package is effectively empty.
- `libmagick++-6.q16-dev` — C++ ImageMagick bindings. Emacs uses the C API (`libmagickwand-dev`). No C++ bindings needed.
- `ispell` — runtime spell checker program, not a build dependency. Belongs in IDE images if needed, not in the build image.
- `iputils-ping` — network diagnostic tool. No role in the Emacs build.
- `openssh-client` — no role in the Emacs build.
- `wget` — not used in any build step in the dev Dockerfile. The Emacs clone uses git directly.
- `curl` — same situation as wget; not used after the apt install step.
- `libcanberra-gtk3-module` — runtime desktop sound event module. Not a build dependency.

**Also add the lean apt config** that the IDE Dockerfile already has. The dev Dockerfile is missing `APT::Install-Recommends "false"`, so every package pulls in its full recommended set. Adding the `99lean` config before the apt install step would reduce install footprint.

**Uncertain — remove and verify with a test build:**
- `libxft-dev` — Xft font rendering is bypassed when building with Cairo/HarfBuzz, but configure may still probe for it.
- `libxcb1-dev`, `libxcb-shape0-dev`, `libx11-xcb-dev` — GTK3 uses XCB internally but Emacs configure may not need these headers directly.
- `xaw3dg-dev`, `libxaw7-dev` — Athena Widget Set. With GTK3 selected, Emacs shouldn't need Xaw, but configure may probe regardless.

---

## IDE image: remove remaining unnecessary -dev packages (post three-stage build)

Once Mercury is isolated into its own build stage (see above), the following Mercury
build-time -dev packages can be removed from the final image:

- `libffi-dev` → replace with `libffi8` (Mercury runtime links against libffi; headers not needed)
- `libicu-dev` → replace with `libicu74` (Mercury uses ICU for Unicode; headers not needed)
- `libreadline-dev` → replace with `libreadline8` (mdb uses readline; headers not needed)
- `libgccjit-13-dev` → consider replacing with `libgccjit0` (runtime-only); needs a test build to confirm AOT compilation still works

Already done: `libgmp-dev`, `libncurses-dev`, `libwebp-dev`, `zlib1g-dev` removed (runtime
counterparts were already present in the package list).

---

## IDE image: pin and verify font installation

Two issues with the current font installation:

1. **Powerline fonts are unversioned** — `git clone https://github.com/powerline/fonts.git` has no commit pin. The installed fonts can change silently between builds. Pin to a specific commit for reproducibility.

2. **Source Code Pro has no integrity check** — downloaded by tag via `wget` with no checksum. Mercury gets sha512 verified; fonts should too.

Note: `doom fonts install` does not exist as a CLI subcommand at the pinned Doom commit. Nerd Font / all-the-icons installation remains a manual post-boot step via `M-x all-the-icons-install-fonts`.

---

## Pin all Emacs packages via straight.el lockfile

Now that the image builds successfully, the next prerequisite is wiring up mercury-mode and flycheck before freezing package versions — packages may change once the Mercury-specific config is active. Steps once that is done:

1. Run a container from the completed image
2. Inside Emacs, run `M-x straight-freeze-versions` — generates `~/.config/emacs/straight/versions/default.el` with the exact commit hash of every installed package
3. Copy that file out of the container and commit it to the repo as `straight-versions.el`
4. Add to the Dockerfile (before `doom sync`):
   ```dockerfile
   COPY --chown=${USERNAME}:${USERNAME} straight-versions.el \
        /home/${USERNAME}/.config/emacs/straight/versions/default.el
   ```

**Why:** The Doom commit pin covers Doom's own packages, but user-declared packages in `packages.el` and any packages Doom leaves unpinned can still drift. The lockfile freezes everything.

---

## Long-horizon idea: Mercury LSP server

No Mercury LSP server currently exists. Building one would be genuinely valuable to the Mercury community and a natural fit for the polyparadigm project's "contribute back" ethos. Four options in ascending order of effort:

**1. Tree-sitter based LSP** (~1-3 months, Mercury-proficient)
Build on a Mercury tree-sitter grammar (write one if it doesn't exist). Provides syntax-based features: folding, symbol navigation, basic completion from visible declarations. No type, mode, or determinism information. Good starting point.

**2. mmc wrapper** (~1-3 months, Mercury-proficient)
Shell out to `mmc` and parse its output. Diagnostics are already handled by flycheck — the incremental work is go-to-definition and completion by parsing Mercury's `.int` interface files and module declarations. The ceiling is low (no semantic analysis) and parsing mmc's text output is fragile since there's no stable machine-readable format.

**3. Shallow standalone parser** (~2-4 months, Mercury-proficient)
Parse Mercury syntax independently, provide go-to-definition by name lookup across modules, completion from declarations. Ignores modes and types. Fragile at module system boundaries.

**4. Deep compiler integration** (~6-12+ months, requires Mercury compiler expertise)
The correct long-term approach. Modify `mmc` to expose an API or run in a persistent server mode, providing real type/mode/determinism information — analogous to what GHC did with GHCi → HLS. Requires deep knowledge of Mercury's HLDS internals. Not viable until well into the Mercury learning track.

Prerequisite for any option: become sufficiently proficient in Mercury first.

---

## Report Mercury compiler bug: profdeep grade fails on parallel conjunctions

File a bug report with the Mercury project at https://bugs.mercurylang.org/

**Summary:** Mercury 22.01.8 crashes with an uncaught exception when compiling the
`integer` standard library module in the `asm_fast.gc.par.stseg.profdeep` grade.

**Error:**
```
Uncaught Mercury exception:
Software Error: predicate `ll_backend.prog_rep.goal_to_goal_rep'/4:
    Unexpected: non-plain conjunction and declarative debugging
```

**Details:**
- The `integer` module uses parallel conjunctions (`&`) for performance.
- The deep profiling instrumentation in `ll_backend.prog_rep.goal_to_goal_rep/4`
  has no handling for non-plain (parallel) conjunctions, causing an internal
  assertion failure.
- Reproducible when building Mercury 22.01.8 from source on Ubuntu 24.04 with
  GCC 13, with `--enable-libgrades=asm_fast.gc.par.stseg.profdeep`.
- Build command that triggers it:
  `make PARALLEL=-jN install` with profdeep in --enable-libgrades.
- Workaround: omit the profdeep grade from the build.

**On submitting a patch:** The quick fix (option A) would be to add a `parallel_conj` case to `goal_to_goal_rep/4` in `compiler/ll_backend/prog_rep.m`, treating it like a plain conjunction. This is probably 5-20 lines of Mercury. Not attempting this patch because: (1) no background in compiler development, (2) not yet sufficiently familiar with Mercury to confidently reason about the HLDS goal representation and what the correct treatment of parallel conjunctions in the profiling IR should be. Filing the report so someone with that context can assess the right fix.
