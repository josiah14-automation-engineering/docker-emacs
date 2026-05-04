# TODO

## Pin all Emacs packages via straight.el lockfile

Once the full Mercury IDE image is working (custom Doom config, mercury-mode, flycheck wired up):

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
