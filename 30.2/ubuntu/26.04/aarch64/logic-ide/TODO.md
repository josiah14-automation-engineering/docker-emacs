# TODO

## Add a mercury-ide README

Same gap as the x86_64/24.04 image's TODO.md: no user-facing README yet. Add one
covering: build command, run command, Wayland setup (this image is built with
`--with-pgtk`, not plain X11 — see `run.sh`'s `WAYLAND_DISPLAY`/`GDK_BACKEND=wayland`
env), shared Nix store bind mounts, mounted project directory example, expected
Mercury version and grade set, expected Doom commit, what works, what does not, and
a 30-second smoke test (much of which is now covered by `smoketest.bats` —
reference it rather than duplicating the steps in prose).

---

## Confirm `asm_fast.gc.profdeep.stseg` (no `.par`) doesn't hit the x86_64 image's
## profiling bug, once the full build completes

BUILDLOG.md documents the reasoning for why this grade is expected to succeed here
(the known Mercury 22.01.8 bug is tied to the `.par` grade component specifically),
but this is a prediction pending the actual build result. If it does fail with the
same `ll_backend.prog_rep.goal_to_goal_rep/4` error, drop `asm_fast.gc.profdeep.stseg`
from `--enable-libgrades` the same way the x86_64 image dropped
`asm_fast.gc.par.stseg.profdeep`, and flag the discrepancy back to
`~/Development/personal/mise/languages/mercury/compilers/22.01.8.nix`, since that
derivation's grade set assumes this grade builds cleanly.

---

## Revisit `libsm6`, `libxaw7`, `libxcb-util1` in the final-image apt list

`ldd` against the real dev-image Emacs binary shows none of these are actually
linked (this image's dev build uses `--with-pgtk`, so there's no Xaw/Xt/SM
toolkit dependency). Left in for now to minimize deviation from the x86_64 list
during initial bring-up; a follow-up pass could drop them and rebuild to confirm
no regression, shrinking the image slightly. Low priority — this is dead weight,
not a correctness bug.

---

## Long-horizon idea: Mercury LSP server

Same item as x86_64/24.04's TODO.md — no Mercury LSP server currently exists. See
that file for the four-option breakdown (tree-sitter grammar, mmc wrapper, shallow
standalone parser, deep compiler integration) and the prerequisite (become
sufficiently proficient in Mercury first). Not duplicated in full here; this is one
project across both images, not a per-image task.

---

## Report Mercury compiler bug: profdeep grade fails on parallel conjunctions
## (if it turns out to still apply here)

Same bug as documented in x86_64/24.04's TODO.md, filed pending confirmation
there. If this image's non-`.par` profdeep grade builds successfully (the expected
outcome — see above), no additional report is needed; the existing report already
covers the `.par` case. If it doesn't build successfully, that's new information
worth adding to whatever gets filed at https://bugs.mercurylang.org/.
