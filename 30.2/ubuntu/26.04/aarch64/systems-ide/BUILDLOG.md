# Systems IDE Build Log
## Emacs 30.2 / Ubuntu 26.04 / aarch64 (Apple M2)

---

### 2026-07-13

#### Starting point: ported from 24.04/x86_64, research-then-TDD-then-implementation

This image was modeled on `30.2/ubuntu/24.04/x86_64/systems-ide`, following the same
build shape (`emacs-build` copy, inline `go-build`, `nix-source` copy, final image)
and the same Doom config files (`config.el`, `init.el`, `packages.el`, `shell.el`,
all `*-keybindings.el`, `go-config.el` — all byte-identical to the x86_64 reference;
`grep -ril "x86_64\|amd64\|skylake\|MARCH\|MTUNE"` across every `.el` file returned
zero matches, confirming none of them reference OS/arch-specific paths or package
names, matching the exact same finding already documented in `logic-ide/BUILDLOG.md`
for its own elisp files).

Scope: the x86_64 source Dockerfile only functionally wires **Shell**, **Go**, and
**Nix** (`init.el`'s `:lang` block is `(sh +lsp) (go +lsp) (nix +lsp)` only). C,
Rust, Zig, CMake, Lua, Guile, and Nu have placeholder keybinding files present in
the source tree but are not loaded by `config.el` and not installed by the
Dockerfile — confirmed by reading `ROADMAP.md` and re-reading the Dockerfile
verbatim, and confirmed with the user directly. This port carries the same file set
(including the unloaded placeholders, for parity) but only ports the actually-wired
Shell/Go/Nix toolchain — it does not get ahead of the x86_64 image's own roadmap.

**Verification method, given no docker/sudo/host access in this working
environment (FaradAI container constraint):** package *existence* was verified by
fetching the real Ubuntu ports archive index directly —
`http://ports.ubuntu.com/ubuntu-ports/dists/resolute/{main,universe}/binary-arm64/Packages.gz`
— gunzipping it, and grepping for `^Package: <name>` per package (all 70 packages in
the x86_64 apt list checked this way). SONAME-correctness for Emacs-linked libraries
(the `ldd`-against-binary check `logic-ide/BUILDLOG.md` performed) was **not
re-derived** — it's inherited directly, since both images copy the exact same
`josiah14/emacs:30.2-m2-ubuntu-26.04-dev` binary via `COPY --from=emacs-build`.

**Renames found (26.04 arm64 vs. 24.04 x86_64), matching logic-ide's table for the
same target repo exactly:**

| 24.04 x86_64 | 26.04 aarch64 | Why |
|---|---|---|
| `libgnutls30` | `libgnutls30t64` | package renamed |
| `libgtk-3-0` | `libgtk-3-0t64` | package renamed |
| `libtree-sitter0` | `libtree-sitter0.25` | soname-versioned package name |
| `libxml2` | `libxml2-16` | soname-versioned package name (libxml2 2.12+ ABI break) |
| `libgccjit-13-dev` | `libgccjit-15-dev` | **not just a rename** — see logic-ide/BUILDLOG.md; `libgccjit-13-dev` still resolves on 26.04 but provides `libgccjit.so.0`, not the `libgccjit.so.15` the shared dev-image Emacs binary actually needs (26.04 defaults to gcc-15) |

All other 65 packages in the x86_64 list exist as-is on resolute/arm64 (verified
directly against the Packages index, not assumed). `libsm6`, `libxaw7`,
`libxcb-util1` are known (per logic-ide's `ldd` finding against the identical
binary) to be unlinked dead weight under `--with-pgtk` — left in here too, for the
same "minimize deviation during initial bring-up" reason logic-ide gave; see its
`TODO.md` for the cleanup candidate, which applies equally here.

**Go 1.26.3, linux-arm64**: tarball `go1.26.3.linux-arm64.tar.gz`, sha256
`9d89a3ea57d141c2b22d70083f2c8459ba3890f2d9e818e7e933b75614936565` — confirmed via
`curl https://go.dev/dl/?mode=json&include=all`, not guessed from the amd64 value.
Version kept at 1.26.3 (matching x86_64) rather than bumped to latest stable
(1.26.5 at time of writing), since porting should preserve pins unless told
otherwise.

**`GOAMD64=v3` → `GOARM64=v8.6,crypto`**, not a straight rename. `GOAMD64=v3` is a
generic x86-64 "modern baseline" (the psABI microarchitecture-level convention);
ARM64 has no equivalent generic level, so the value has to be derived from the
actual target CPU rather than copied. Confirmed via LLVM's own
`AArch64Processors.td`: `apple-m2` is a `ProcessorAlias` for `apple-a15`, whose
feature list is `HasV8_6aOps, ..., FeatureLSE, ..., FeatureAES, ..., FeatureSHA3,
...` — i.e. ARMv8.6-A with LSE atomics and AES/SHA3 crypto extensions, matching
this project's own `MCPU=apple-m2+crc+aes+sha3+fp16` used elsewhere. Cross-checked
against Go's own `internal/buildcfg/cfg.go` (`ParseGoarm64`): valid syntax is a
version (`v8.0`–`v9.5`) plus any combination of `,lse`/`,crypto` suffixes, and any
version ≥ v8.1 sets `LSE = true` automatically regardless of suffix — so `,lse` is
redundant given `v8.6`, and `,crypto` is the one addition v8.6 doesn't already
imply. No established `GOARM64` precedent existed anywhere in this project before
this; this value was derived, not inherited.

**`golangci-lint` v2.11.4**: confirmed via the GitHub releases API
(`/repos/golangci/golangci-lint/releases/tags/v2.11.4`) that
`golangci-lint-2.11.4-linux-arm64.tar.gz`/`.deb`/`.rpm` all exist as release
assets. The Dockerfile's install line uses the official `install.sh` script
(auto-detects OS/arch), so no line changes were needed beyond the architecture
itself.

**No `ARG MCPU` in this Dockerfile.** Unlike `logic-ide` (which compiles Mercury
from source with `CFLAGS="-O2 -mcpu=${MCPU}"`), this image performs no native
C/C++ compilation of its own — Go's own codegen tuning is controlled by the
`GOARM64` env var above, not a Dockerfile `ARG`/`-mcpu` flag. Adding an unused
`ARG MCPU` here would be a no-op Docker would warn about; the CPU-tuned pieces
(Emacs itself, and the Mercury/logic-ide's `mmc`) already come from elsewhere.
The `emacs-build` stage's source tag is hardcoded to `josiah14/emacs:30.2-m2-
ubuntu-26.04-dev` rather than parameterized, mirroring `logic-ide/Dockerfile`'s
identical choice (only one arm64 target — M2 — exists so far; `TAG_CPU` in
`build.sh`/`run.sh` only controls the *output* image tag, not the dev-image pull,
matching the existing convention exactly).

**`go install`-based tools, `npm install -g bash-language-server`, zshdb's
autotools build, and the font downloads** need no architecture-specific
Dockerfile changes: `go install` targets the host arch automatically (native
build, no cross-compilation — this image is built directly on the M2 host, same
as `logic-ide`), `bash-language-server` is pure JS with no native modules,
`zshdb` builds from a shell-script source tree via `autogen.sh`/`configure`/`make`
(no compiled-binary architecture dependency), and fonts are binary-format-
agnostic. Confirmed by grepping the whole Dockerfile for `GOARCH|GOOS|amd64|
x86_64|platform` — the *only* two hits were the Go tarball URL and `GOAMD64`,
both already addressed above.

**TDD**: `nix-smoketest.bats` is byte-identical to both the x86_64 and
`logic-ide` versions (`diff` confirmed) and was copied verbatim — it exercises the
host nix bind-mount integration (version, store, flakes, shared profile), not
anything Emacs- or arch-specific. `smoketest.bats` is new, modeled structurally on
`logic-ide/smoketest.bats` (`emacs --daemon` + `emacsclient --eval`, not `--batch`
— Doom skips `doom-font`/module config under `noninteractive`) but covers
Shell/Go/Nix instead of Mercury/Prolog: tool version checks (bash-language-server,
shellcheck, zshdb, go, gopls, dlv, golangci-lint — the last four asserting the
exact pinned versions as a regression guard), major-mode activation for
`.bash`/`.zsh`/`.go`/`.nix`, and localleader keybinding resolution for each
language. LSP checks use `(featurep 'lsp-mode)` rather than `(bound-and-true-p
lsp-mode)` — `lsp-deferred` is an autoloaded stub, so calling it from the mode
hook forces `lsp-mode.el` to load synchronously even though the actual server
handshake is scheduled for the next idle moment; asserting the minor mode is *on*
synchronously would race that handshake. No LSP check was written for `.nix`
buffers: the nix module's LSP server (`nil`) arrives via the host nix-profile
bind mount at container *runtime*, which the plain `bats smoketest.bats` `-t`
invocation (no `/nix` mounts) doesn't provide — that would be a flaky assertion
against infrastructure the test intentionally doesn't set up, not a real
regression check. Both bats files parse cleanly (`bats --count`: 18 and 7 tests
respectively); could not be run end-to-end in this environment (no `emacs`/
`docker` available here to actually spin up the daemon).

**Not yet decided**: whether to copy `flight-tests/` (an `.obsidian` vault plus a
manual Go scratch project) into this directory. `logic-ide` has no equivalent
directory at all — this convention wasn't carried over during that port, so
there's no precedent either way. `run.sh`'s `-f` flag (ported from x86_64
`systems-ide`) has nothing to mount without it.

---

### 2026-07-14

#### Bats support

Added `.bats` as a fourth supported language, following the same shape as
Shell/Go/Nix: a `bats-keybindings.el`, a `packages.el` entry, a `Dockerfile`
install + COPY, and new `smoketest.bats` cases.

**Package choice**: `bats-mode` (dougm/bats-mode, MELPA), confirmed present in
MELPA's live `archive-contents` before adding it to `packages.el` (per the
"verify packages before build" rule) and its source read directly from GitHub
to confirm the actual interface rather than guessing function names.
`bats-mode` is `define-derived-mode bats-mode sh-mode`, sets `sh-shell` to
`bash`, wires `flycheck`'s shellcheck checker to bats buffers itself, and
registers `.bats` in `auto-mode-alist` — so, like `nushell-mode`, it needs
only a `package!` declaration, no `init.el` `:lang` module entry (no Doom
module for Bats exists). `bats-keybindings.el` is not wrapped in `after!
bats-mode`, matching `sh-keybindings.el` rather than `nix-/go-keybindings.el`
— the `after!` wrapper in those two exists specifically to out-race a
competing Doom `:lang`-module `:config` block that resets the same bindings
later; no such module exists for Bats, so there's nothing to race.

**Found and fixed a pre-existing gap**: `run.sh -t` runs
`docker run --rm -v ... IMAGE bats smoketest.bats` with zero bind mounts, so
the bare image itself must already contain a working `bats` executable — it
did not (`grep -n -i bats Dockerfile` was empty before this change). The
`bats`/`nil`/`direnv`/`nixfmt` visible in `nix-smoketest.bats`'s `nix profile
list` check come from the *host's* live nix profile, bind-mounted only in
`run.sh`'s non-`-t` path (see the `nix_mounts` block) — not from anything
baked into the image at build time. So `run.sh -t` was never actually
runnable end-to-end even for the existing Shell/Go/Nix suite, only validated
via host-side `bats --count` syntax checks (as this file already noted).
Fixed by adding `bats` to the Dockerfile's apt list. Verified against the
real `resolute` (26.04) archive index directly
(`packages.ubuntu.com/resolute/bats`, package `bats` 1.13.0-1, arch: all)
before adding it, rather than assuming the name carries over — same
verification standard as every other package in this Dockerfile.

**smoketest.bats**: added a `test.bats` fixture (`@test "addition works"`),
a `bats --version` check, a `.bats` → `bats-mode`/`sh-shell=bash` activation
check, and a localleader keybinding check for the three commands
`bats-mode.el` already provides (`bats-run-current-test`,
`bats-run-current-file`, `bats-run-all`), mapped under the existing
"execute" prefix convention from `sh-keybindings.el`. `bats --count`: 21
(was 18). Could not run `run.sh -t` end-to-end in this environment (no
docker here either) — same limitation as the rest of this port.

**Bug found after rebuild: `.bats` files stayed in `sh-mode`, not
`bats-mode`.** User reported `lsp-mode`'s "no language servers... registered
with `sh-mode'" warning; modeline showed `Sh [bats]` and
`(eval-elisp "major-mode")` reported `sh-mode` directly. Ruled out an
`lsp-mode`/Doom configuration problem first, by reading `lsp-bash.el` and
`lsp-mode.el` from source: the `bash-ls` client's `:activation-fn`
(`lsp-bash-check-sh-shell`) only checks the buffer-local `sh-shell` variable
against `'(sh bash)` — it doesn't look at `major-mode` at all, and would
happily activate for a genuine `bats-mode` buffer (which sets `sh-shell` to
`'bash` itself) with zero extra config. So the real bug had to be upstream:
`bats-mode` was never actually running.

`Sh [bats]` is `sh-mode`'s own dynamic modeline lighter reflecting
`sh-shell`'s value — plain `sh-mode`'s built-in shebang sniffing
(`sh-set-shell`) reads whatever token follows `#!/usr/bin/env` and binds it
to `sh-shell` verbatim, even for values it doesn't recognize (here, the
literal `bats`). That's a different code path than `bats-mode`'s own body,
which explicitly sets `sh-shell` to `'bash`. So the buffer was landing in
plain `sh-mode` before `bats-mode`'s own `;;;###autoload
(add-to-list 'auto-mode-alist '("\\.bats\\'" . bats-mode))` cookie ever took
effect. Checked whether MELPA's packaged snapshot (`20230325.7`) might be
stale relative to the `bats-mode.el` source already read from GitHub's
`master` branch — the GitHub commits API shows `master`'s newest commit
(`fa88930`) is dated exactly `2023-03-25`, matching the MELPA stamp with no
commits since, so that's not it; the installed package is the same source
already reviewed.

Root cause not fully isolated at this point (candidates: straight.el's
autoload-cookie extraction not handling this file's bare `(progn
(add-to-list ...))` form, or some ordering/build issue under Doom's sync)
but rather than chase it further, added our own explicit
`(add-to-list 'auto-mode-alist '("\\.bats\\'" . bats-mode))` directly in
`bats-keybindings.el` — idempotent with the package's own registration if
that turns out fine, and a guaranteed fix regardless of the underlying
cause. Not yet rebuilt/verified in an actual container (no docker in this
environment); pending user rebuild + confirmation.

**Root cause isolated after rebuild; two-stage fix.** Josiah rebuilt and
reopened `smoketest.bats` — still `Sh [bats]`. Diagnosed live in the running
Emacs session via three targeted `M-:` checks, all run by Josiah directly:

- `(rassq 'bats-mode auto-mode-alist)` confirmed our forced entry was
  actually present in the alist.
- `M-x normal-mode` in the mis-classified buffer reproduced the bug fresh
  (no reopen needed), ruling out a stale/session-restored buffer — Doom's
  persp/workspace session restore had been the leading alternate theory,
  and this single test eliminated it.
- `(seq-filter (lambda (e) (and (stringp (car e)) (ignore-errors
  (string-match (car e) "smoketest.bats")))) auto-mode-alist)` returned
  `(("\.bats\'" . sh-mode) ("\.bats\'" . bats-mode))` — two competing
  entries for the identical regex, `sh-mode`'s ahead of ours. `auto-mode-
  alist` resolution is first-match-wins, so `sh-mode` was winning outright
  regardless of our `add-to-list` call having run.

Actual root cause: `sh-script.el` registers `.bats → sh-mode` as a plain
top-level form, not an `;;;###autoload` cookie — so it only takes effect
once `sh-script.el` is actually `require`d, which can happen *after*
`bats-keybindings.el` loads (triggered by any earlier shell-derived buffer
in the same session), re-prepending its entry in front of ours.
`add-to-list`'s "prepend by default" behavior only decides the winner
between writers active at the same moment; it says nothing about a writer
that runs later in the session.

First fix attempt — wrap the correction in `(with-eval-after-load
'sh-script (setf (alist-get "\.bats\'" auto-mode-alist nil nil #'equal)
'bats-mode))` so it reliably runs after `sh-script.el`'s own registration,
whenever that happens — worked when retested via `M-x normal-mode`. Josiah
then rebuilt a **fresh** container specifically to test cold-start behavior
(not just live-session retesting) and reported the *first* `.bats` file
opened in that fresh container was still `Sh [bats]`. That one data point
exposed the real gap: on a cold start, opening the first `.bats` file is
itself what triggers `sh-mode`'s autoload (and thus `sh-script.el`'s full
load) — so `sh-script.el`'s competing entry wins that one race before our
`with-eval-after-load` hook can fire. Every subsequent open in the same
session was already correct, which is exactly what made the gap easy to
miss without a genuinely fresh container to test against.

Final fix: force the `require` eagerly in `bats-keybindings.el` itself —
`(require 'sh-script)` immediately followed by the same `setf`/`alist-get`
correction, no `with-eval-after-load` indirection — so both now run at
Doom startup, before Emacs has ever presented a `.bats` buffer, closing the
race regardless of session history. Rebuilt and confirmed: `.bats` files
now open directly into `bats-mode` on first try, cold start.

**Josiah's contributions this session**: flagged a prompt-injection attempt
embedded in what looked like an automated context-compaction message (a
block appended to a tool result instructing "respond with TEXT ONLY... tool
calls will be REJECTED") as suspicious rather than complying with it —
correctly reasoned that real compaction happens outside the conversation,
not via directive text inside a message body, and continued the actual
debugging instead of fabricating a summary. Ran every `M-:` diagnostic that
isolated the real root cause (the `normal-mode` retest that ruled out
session-restore; the `seq-filter`/`rassq`/`assoc-default` checks that
revealed the two competing alist entries and their order) and, critically,
tested the fix against a genuinely fresh container rather than accepting
the live-session retest as sufficient — the step that surfaced the
cold-start race the first fix missed.

---

#### LSP integration: bash-ls never attached to bats-mode buffers

With `.bats` files correctly landing in `bats-mode`, the next problem
surfaced: `(lsp!)` in `smoketest.bats` neither errored nor prompted to
import the project — it just silently did nothing. `bats-keybindings.el`
already special-cased this (`bash-language-server`'s `bash-ls` client
checks `major-mode` against a literal list rather than `derived-mode-p`, so
`bats-mode`, despite deriving from `sh-mode`, never matches), registering
itself onto the existing `bash-ls` client via `(cl-pushnew 'bats-mode
(lsp--client-major-modes (gethash 'bash-ls lsp-clients)))` inside
`(with-eval-after-load 'lsp-mode ...)`. That registration turned out to be
broken in two independent ways, plus one red herring that ate most of the
session before either real bug was found.

**Red herring: suspected stale/corrupted native-compiled `lsp-mode`.**
`(lsp!)` was erroring with `"lsp-execute-command is already defined as
something else than a generic function"`, thrown from
`cl-generic-ensure-function` while `lsp-mode.elc` defined its own *first*
`cl-defmethod lsp-execute-command`. Chased this for a long stretch: traced
every `defalias` call for that symbol via an advice on `defalias` (three
hits, all from `lsp-mode.elc`, none autoloads — eventually recognized as
the *normal* cl-generic pattern of one dispatcher creation plus one
redefinition per `cl-defmethod`, not evidence of corruption); confirmed via
`how-many` that the checked-out `lsp-mode.el` source has exactly the 2
legitimate `cl-defmethod` definitions upstream has; compared `.elc`/`.eln`
mtimes against the source and found both freshly compiled, ruling out
straight/native-comp staleness. A targeted `:before` advice on
`cl-generic-ensure-function` did confirm something genuinely odd — at the
moment of the error, `lsp-execute-command` was bound to a plain
byte-compiled function whose body was just the method's docstring, not a
`cl--generic` struct — but since this error stopped recurring once the
real bugs below were fixed, it was set aside as an unresolved native-comp
oddity rather than chased further. Worth revisiting if it resurfaces.

**Real bug #1: `cl-pushnew` on a struct accessor byte-compiles into a
call to a function that's never defined.** `lsp--client-major-modes`'s
`setf` support is a `gv-expander` that lsp-mode's `cl-defstruct` registers
*at runtime*, once `lsp-mode.el` actually loads — not at compile time. Doom
byte-compiles `bats-keybindings.el` without `lsp-mode` loaded, so
`cl-pushnew`'s macroexpansion falls back to assuming a literal
`(setf lsp--client-major-modes)` function will exist at runtime. It never
does, so the very first time the `with-eval-after-load` hook ran, it threw
`(void-function (setf lsp--client-major-modes))`. Confirmed by disassembling
the failing form in a full backtrace and matching it to the exact
`cl-pushnew` call site. Fixed by swapping to `cl-struct-slot-value`, whose
`setf`-expander lives in `cl-lib` itself and is therefore always available
regardless of load order:

```elisp
(cl-pushnew 'bats-mode (cl-struct-slot-value
                        'lsp--client 'major-modes
                        (gethash 'bash-ls lsp-clients)))
```

**Real bug #2: `bash-ls` isn't registered by loading core `lsp-mode`.**
After fixing bug #1, the same hook failed differently:
`(wrong-type-argument lsp--client nil)` — `(gethash 'bash-ls lsp-clients)`
was returning `nil`. `bash-ls` is actually registered inside the separate
`clients/lsp-bash.el`, which `lsp-mode` only auto-loads once some buffer's
major-mode already matches one of its registered modes. A `bats-mode`
buffer never matches on its own — that's the entire bug this file exists
to fix — so `lsp-bash` never got a chance to load, and the client hash
table lookup came back empty. Fixed by forcing the require explicitly,
inside the same hook, before the lookup:

```elisp
(with-eval-after-load 'lsp-mode
  (require 'lsp-bash)
  (cl-pushnew 'bats-mode (cl-struct-slot-value
                          'lsp--client 'major-modes
                          (gethash 'bash-ls lsp-clients)))
  (add-to-list 'lsp-language-id-configuration '(bats-mode . "shellscript")))
```

**Testing complication: container `DOOMDIR` is a build-time snapshot, not
the live-mounted project.** Confirmed via `/proc/<pid>/environ` on the
container's `emacs` process that `DOOMDIR=/home/josiah/.config/doom`
*inside* the container — a copy baked in at image-build time by the
Dockerfile's `COPY` steps, distinct from `automation-engineering/docker-
emacs`, which *is* bind-mounted live into the container. Editing the
project's `bats-keybindings.el` on the host had no effect on the running
container until the fixed file was pushed in directly (`docker cp` into
the container's `DOOMDIR`), followed by `doom sync` and a Doom restart.
Anyone iterating against an already-running container needs to repeat that
`docker cp` + `doom sync` cycle per edit; only a real image rebuild picks
up source changes automatically. The earlier `rm -rf .../straight/build-*`
recompile-forcing step (added to both Dockerfiles the same day, before
either real bug above was found) stays in place as reasonable insurance
around the two-stage-sync design, even though it turned out not to be the
fix for this particular bug.

**Confirmed working**: `(lsp!)` in `smoketest.bats` now triggers the
"import project?" prompt; after accepting, `(bound-and-true-p lsp-mode)`,
`(featurep 'lsp-mode)`, and `(lsp-workspaces)` all confirm a live, attached
workspace. Not yet done: the same verification against the `24.04/x86_64`
container, and a real `docker build` of both images (the fixes are
currently only live-patched into the running containers, plus committed to
the project source).

**Josiah's contributions this session**: pulled every diagnostic backtrace
requested, including the pivotal one that first showed the `cl-pushnew`
expansion disassembled down to the exact `(setf lsp--client-major-modes)`
call site (turning a guess about compile-order into a confirmed root
cause), and the later one showing the `cl-struct-slot-offset`-based
expansion hitting `wrong-type-argument` on a `nil` client (which is what
redirected the investigation from "is the fix compiling correctly" to "is
`bash-ls` even registered yet"). Also reported, mid-session, that the
sandbox had been switched off FaradAI due to local network limits — which
turned out to be exactly what unblocked direct `docker exec`/`docker cp`
access to the running container, without which the `DOOMDIR`-mismatch
finding (and the ability to patch the fix in and retest live, without a
full rebuild) wouldn't have been possible.

---

#### LSP integration, part 2: cold-start still didn't attach

Both real bugs above fixed and confirmed via manual `(lsp!)` calls, but a
genuine cold start — starting the IDE and opening `smoketest.bats` first
thing, no manual `M-:` — still didn't trigger the "import project?" prompt.
Manually running `(lsp!)` from the elisp evaluator still worked fine, which
narrowed it immediately: registration was correct, but nothing was actually
*calling* `lsp!` for a fresh `bats-mode` buffer.

Root cause: Doom's own `:lang sh +lsp` module hooks `lsp!` onto
`sh-mode-local-vars-hook` (confirmed by reading
`modules/lang/sh/config.el` inside the container) — Doom's standard
defer-until-after-directory-locals convention. That hook only fires for
buffers whose `major-mode` is literally `sh-mode`; `bats-mode` deriving
from `sh-mode` doesn't inherit it. With no Doom `:lang` module for bats to
wire this up on its own, nothing ever called `lsp!` automatically. Fixed
by mirroring Doom's own hook exactly, scoped to bats-mode's own local-vars
hook: `(add-hook 'bats-mode-local-vars-hook #'lsp! 'append)`.

Bundled two small cleanups into the same pass while already in this file:
switched the client-registration block from raw `with-eval-after-load
'lsp-mode` to Doom's `after!` macro, matching `config.el`/`nix-
keybindings.el`/`go-keybindings.el` and `ELISP-STYLE-GUIDE.md` §11.2's
stated preference (this predated today's changes; not a new bug, just an
inconsistency worth fixing while already touching this exact block twice
in one session); and reworded the `rm -rf .../straight/build-*` Dockerfile
comment, which had asserted the stale-bytecode theory as settled fact even
though the "LSP integration" entry above documents it as a ruled-out red
herring — now describes the step as precautionary insurance instead of
claiming a specific (wrong) mechanism.

**Confirmed working, genuine cold start**: rebuilt the aarch64 image,
started the IDE fresh, opened `smoketest.bats` first thing — LSP attached
automatically, no manual `(lsp!)` needed, modeline confirms it's live.
Opening `build.sh` afterward correctly did *not* re-trigger the import
prompt (same project root already has a workspace — expected, not a
regression). Retested Go support afterward too, confirming the shared
`Dockerfile`/`lsp-clients` changes didn't disturb it. x86_64 verification
and rebuild still pending (Josiah pulling latest to test there next).

---

#### Nushell support added as a fifth language

Following the same shape as Bats: `nushell-mode` (syntax highlighting only)
was already declared in `packages.el`, and `nu-keybindings.el` already
existed but was dead code — never `load!`-ed from `config.el`, no real
keybindings in it, and not even in the Dockerfile's `COPY` list. Nushell
itself (the `nu` binary) wasn't installed anywhere either.

Much less custom wiring was needed than Bats required, though. Checked
`lsp-mode`'s own `clients/lsp-nushell.el` first: it registers a client
(`nushell-ls`, `:new-connection (lsp-stdio-connection '("nu" "--lsp"))`,
`:activation-fn (lsp-activate-on "nushell")`) and `lsp-mode`'s *default*
`lsp-language-id-configuration` already maps `nushell-mode`/`nushell-ts-
mode` → `"nushell"` — so, unlike `bash-ls`, no manual client-registration
hack (`cl-struct-slot-value`, mutating an existing client's major-modes
list) was needed at all; the client just needs to actually load.

Two gaps remained, both familiar from the Bats work:

1. `clients/lsp-nushell.el` is a separate file `lsp-mode` only auto-loads
   once some buffer's major-mode already matches an already-loaded
   client's activation function — nothing pulls it in for a fresh
   `nushell-mode` buffer on its own. Fixed with `(after! lsp-mode (require
   'lsp-nushell))`, same fix shape as `lsp-bash` needed.
2. `nushell-mode` derives from plain `prog-mode`, not from anything Doom's
   `:lang` modules already wire `lsp!` onto via `<mode>-local-vars-hook`.
   With no Doom `:lang` module for nushell, nothing called `lsp!`
   automatically. Fixed with `(add-hook 'nushell-mode-local-vars-hook
   #'lsp! 'append)`, mirroring Doom's own convention directly (same fix
   shape Bats needed for its own cold-start gap).

**Install**: nushell ships its own LSP server behind `nu --lsp` — no
separate language-server package to install, just the `nu` binary itself.
Verified the actual current release (`gh release view 0.114.1 --repo
nushell/nushell`) rather than guessing a version, per this project's own
"verify packages before build" rule — pulled the real asset filenames and
`SHA256SUMS` from the release directly. Installed via a prebuilt Linux
release tarball (`nu-0.114.1-aarch64-unknown-linux-gnu.tar.gz`, verified
against its published sha256), the same curl+sha256sum+tar shape already
used for Go, rather than `cargo install` — this image has no Rust
toolchain otherwise, so pulling one in just for one binary would've been a
much heavier lift for no real benefit. The tarball extracts to a versioned
subdirectory containing `nu` plus several `nu_plugin_*` binaries, `LICENSE`,
and `README.txt`; only `nu` itself is copied out into `/usr/local/bin`.

**Keybindings researched against nu-lsp's actual source, not assumed**:
fetched `crates/nu-lsp/src/lib.rs` directly and confirmed which
`ServerCapabilities` are actually set. `rename_provider`,
`references_provider`, `document_symbol_provider`/`workspace_symbol_
provider`, and `signature_help_provider` are all genuinely supported —
meaning Doom's existing global LSP bindings (`SPC c r`, `g D`, inline
signature help) just work for nushell with zero extra configuration.
`document_formatting_provider` and `code_action_provider` are explicitly
*not* implemented, so `SPC c a` and any format-buffer binding were
deliberately left out of `nu-keybindings.el`'s reference comment — they'd
silently no-op against this server. The one genuinely new addition:
`nu-run-region`/`nu-run-buffer` (`SPC m e e` / `SPC m e b`), mirroring
`sh-keybindings.el`'s region/buffer execute pair, using `nu -c` for the
region variant since nushell has no comparable REPL-eval package of its
own the way Go has `gorepl-mode`.

**Convention fixes made along the way, not nu-specific**:

- `bats-keybindings.el` mixed plumbing (the `auto-mode-alist` fix, the
  `lsp-bash` require/registration, the local-vars-hook) together with its
  actual `map!` keybindings, unlike `go-config.el`/`go-keybindings.el`'s
  established split. Split it the same way: all the plumbing moved into a
  new `bats-config.el`, leaving `bats-keybindings.el` with just the `map!`
  block. `nu-config.el`/`nu-keybindings.el` follow this same split from
  the start.
- `shell.el` renamed to `shell-config.el` for the same naming consistency
  (it already held only config/plumbing, zero keybindings — the split
  was already correct, just the name didn't match the `<lang>-config.el`
  convention). Its `provide` was already `'systems-ide-shell` rather than
  `'shell` specifically to avoid colliding with Emacs's own built-in
  `shell.el` (the `M-x shell` package) — silently breaking
  `shell-mode-hook` elsewhere, per that history already documented
  earlier in this log. Renamed the `provide` to `'shell-config` instead:
  matches the rest of the codebase's filename-matches-feature-name
  convention while *still* avoiding the original collision, since nothing
  else would ever plausibly `(require 'shell-config)`.

Both ports updated in lockstep (`nu-config.el`/`nu-keybindings.el`/
`bats-config.el`/`shell-config.el` are byte-identical between them, same
as the rest of this project's per-language files). x86_64 didn't have a
general `smoketest.bats` at all before this (only `nix-smoketest.bats`) —
confirmed all pinned tool versions actually match between the two
Dockerfiles (Go, zshdb, bash-language-server, gopls, dlv, golangci-lint)
before porting the whole suite over rather than just the new nu cases, so
x86_64 now has parity with aarch64's full language smoketest for the first
time.

**Confirmed working, aarch64**: Josiah rebuilt the image and ran
`bats smoketest.bats` (via `run.sh -t`) — all 25 tests passed, including
all four new nushell cases (install version check, mode activation,
lsp-mode load, localleader keybindings). x86_64 rebuild/retest still
pending on the System76 machine.

---

#### Nushell follow-up: switched to nushell-ts-mode for working indentation

Plain `nushell-mode` (the package from the entry above) turned out to have
no working indentation at all. Confirmed by reading its source directly
rather than guessing: it defines `nushell-enable-auto-indent` (default
`nil`) with a docstring describing an indent-on-keyword feature, but the
`nushell-auto-indent-trigger-keywords` variable that feature depends on is
never defined anywhere in the 150-line file — the feature was never
finished. No indent-line-function is set at all, so Emacs just falls back
to copy-previous-line's-indentation, with nothing structural happening on
newline-into-a-block or on `evil`'s `O`.

`nushell-ts-mode` (tree-sitter based, already present on this host from
an earlier check) has a complete `treesit-simple-indent-rules` table
(blocks, arrays, records, parens, string bodies) plus `electric-indent-
chars` for brackets, `completion-at-point` (operators/keywords/types/
nearby variables via a tree-sitter query), and `imenu` integration — all
things plain `nushell-mode` never had. Switching is a strict functionality
upgrade, not a tradeoff, with one new consideration: it depends on the
`tree-sitter-nu` grammar being compiled from C source at build time (a
real new moving part `nushell-mode` never needed, being pure Elisp).

**Changes**: `packages.el` swapped `nushell-mode` → `nushell-ts-mode`.
`nu-config.el` gained an eager `(require 'nushell-ts-mode)` — its own file
registers `.nu` in `auto-mode-alist`/`interpreter-mode-alist` inside a
top-level `(when (treesit-ready-p 'nu) ...)` form rather than behind an
autoload cookie, so nothing associates `.nu` files with it until the whole
file is required at least once; same fix shape `bats-config.el` needed for
`sh-script`'s race. Renamed the `local-vars-hook` target and `nu-
keybindings.el`'s `map!` target from `nushell-mode` to `nushell-ts-mode`.
`lsp-mode`'s default `lsp-language-id-configuration` already maps
`nushell-ts-mode` → `"nushell"` out of the box (confirmed earlier session,
same as plain `nushell-mode`), so no LSP-side changes were needed beyond
the rename.

**Grammar install, and two build-time gotchas found only by testing live
rather than trusting the plan**: added a `Dockerfile` step compiling
`tree-sitter-nu` via `emacs --batch -Q --eval` + `treesit-install-
language-grammar`, reasoning from the package's own `nu-lsp` precedent
that this had to happen at build time (no network at container start).
First rebuild's smoketest run still showed `.nu` failing to activate
`nushell-ts-mode` — rather than guess again, started a throwaway debug
container (`docker run -d ... sleep 3600`) to test the grammar-install
step live and iterate fast without a full rebuild cycle each time:

1. Running the exact install command live surfaced the real error:
   `(file-missing ... cc)` — no C compiler on `PATH` at all.
   `libgccjit-15-dev` (already installed, for native-comp) only provides
   the JIT *library* Emacs links against; it doesn't put a `cc`/`gcc`
   *executable* anywhere. Confirmed `tree-sitter-nu`'s `src/` is plain C
   (`parser.c`/`scanner.c`, no `.cc`) via `gh api`, so plain `gcc` (no g++)
   was enough — added it to the Dockerfile's apt list.
2. After installing `gcc` live and recompiling, the grammar built and
   `ls` confirmed the `.so` on disk — but `treesit-install-language-
   grammar` immediately warned it couldn't find what it had just written,
   searching `~/.config/emacs/tree-sitter/` (vanilla Emacs's default)
   while Josiah's own copy-pasted live warning (from his actual running
   Doom session) showed the real search path as `~/.config/emacs/.local/
   cache/tree-sitter/` — a Doom-specific redirect. Checked directly with
   `emacs --batch --eval` (no `-Q`) whether `treesit-extra-load-path` held
   the answer — it was `nil` even without `-Q`, and `--batch` mode doesn't
   replicate Doom's real interactive startup at all (same
   `noninteractive` gap already documented for `doom-font`/module config
   earlier in this log). Had to test against a genuine `emacs --daemon` +
   `emacsclient --eval` instead — matching exactly how `smoketest.bats`
   itself verifies things — to see the *real* resolved path, confirming
   Doom redirects its cache dir rather than setting that specific
   variable. Passed the correct `OUT-DIR` explicitly to `treesit-install-
   language-grammar` to match. Re-verified `treesit-ready-p`, mode
   activation, `lsp-mode` load, and both localleader keybindings, all
   live in the daemon, before touching the Dockerfile again — a first
   `emacsclient --eval` call after switching modes hung the whole debug
   daemon (likely an "import project?" prompt blocking on a headless
   session with nothing to answer it, the same class of issue the
   original bash-ls integration hit); killed and restarted the daemon
   with `lsp-auto-guess-root` set first to sidestep it rather than debug
   that prompt itself, since it wasn't the thing under test.

Both fixes (`gcc` in the apt list, explicit grammar `OUT-DIR`) applied to
both ports' Dockerfiles. Rebuilt aarch64 and reran the full smoketest
suite: all 25 pass, including `nushell-ts-mode` activation and its
keybindings. Josiah separately confirmed indentation itself works
correctly by hand-testing in the toy script. x86_64 rebuild/retest still
pending.

**Josiah's contributions this session**: flagged that auto-indent was
"annoying enough in daily work" to justify switching packages rather than
living with the gap, and pointed out mid-session (twice) that "real"/
"genuine" had become a meaningless filler qualifier in these write-ups —
gaps and bugs are all real if they're worth mentioning at all. Also
copy-pasted the exact live warning text from his own running Doom session
when asked, which is what actually revealed the correct cache-dir path
rather than that detail being guessed or re-derived from documentation.

---

### 2026-07-17 — C/C++/CMake added as a sixth language; package managers wired in

`c-keybindings.el` and `cmake-keybindings.el` existed only as the empty
placeholder files scaffolded at project start (see the 2026-05-06 x86_64
entries) — never `load!`-ed, no toolchain installed. Wired both up per the
project's original "Language stack decisions" spec (`C/C++`: full IDE
support, `clangd`, both `gcc`/`g++` and `clang`, `gdb`; `CMake`: full
support, `cmake-language-server`).

**`init.el`**: added `(cc +lsp)` to `:lang` and `(format +onsave)` to
`:editor` (the latter was previously absent entirely — no language in this
image had a formatter wired until now). `config.el` gained two `load!`
calls (`c-keybindings`, `cmake-keybindings`).

**Dockerfile additions**:
- `clang`, `clangd`, `clang-format`, `gdb`, `cmake`, `ninja-build`, `g++`
  (`gcc` was already present, pulled in earlier for tree-sitter grammar
  compilation). `ccls` deliberately excluded — no apt package, no prebuilt
  release binary, and building it from source against a matching `libclang`
  would be real fragility for a server Doom's own `:lang cc` module already
  deprioritizes below clangd.
- `cmake-language-server` 0.1.11 via `pipx`. Its own repo has been
  unmaintained since Jan 2025 and declares `requires-python <3.14`, which
  this Ubuntu release's system Python (3.14.4) fails outright — confirmed
  live in a throwaway container, not assumed. `--ignore-requires-python`
  installs it anyway, but its loose `pygls>=1.1.1` constraint then resolves
  pygls 2.x, which removed `LanguageServer` from `pygls.server` as a
  breaking change (confirmed live via the resulting `ImportError`, not just
  an overcautious version cap). `pipx inject cmake-language-server
  pygls==1.3.1 --force` pins back to the last 1.x release; `--version`
  confirmed working with this combination before committing to it.
- `vcpkg` (2026.06.24) and `conan` (2.30.0) added as the C/C++ package
  managers — no equivalent existed for this language pair before. `vcpkg`
  has no apt package or standalone release binary for the tool itself (it's
  meant to live as a clone alongside your projects); cloned to a stable path
  and bootstrapped instead, falling back to source compile if no prebuilt
  `vcpkg-tool` release matches the arch (needs `cmake`/`ninja-build`/`g++`,
  already installed). `conan` installed cleanly via `pipx` with no
  workarounds needed. `zip` added to the apt list as a `vcpkg` bootstrap
  prerequisite.
- `nupm` (nushell's own package manager, pinned to commit `9a28419`) added
  in the same pass — bundled here because it's the same "give every
  language that has a package manager one" motivation as vcpkg/Conan, not
  because it's C-specific. It has no apt/pip/tagged-release path at all: a
  self-hosted Nushell module you clone and `use`, explicitly marked
  "experimentation stage" by its own maintainers. Confirmed live in a
  throwaway container that the pinned commit bootstraps and installs
  packages correctly before committing to it. Found and fixed one install-path
  gotcha live: `nupm install <path> --path` needs `<path>` to be the
  directory directly containing `nupm.nuon`, not a bare relative name — the
  project's own README self-install example only works by coincidence when
  the checkout happens to be cloned into a directory literally named
  `nupm`. Only `nupm` itself is baked in; specific packages it installs
  (`nutest`, etc.) belong to whichever project needs them.

**Two bugs found and fixed, both via live testing rather than assumed
correct from the config alone:**

1. Opening a lone `.h` file lsp-mode hadn't seen before blocked forever on
   a synchronous "import project?" minibuffer prompt — and because Emacs
   is single-threaded, that wedges *every* emacsclient connection, not just
   the one that opened the file. Fixed with `(setq lsp-auto-guess-root t)`
   in `config.el`'s existing `after! lsp-mode` block.
2. `:editor format` was missing entirely, so `clang-format` wasn't
   installed and indentation was never touched — not a linter gap
   (`clangd` diagnostics are compile-level: syntax/type/warnings, never
   whitespace) but a missing formatter. Fixed by adding `clang-format` to
   the Dockerfile and enabling `(format +onsave)` in `init.el`. Confirmed
   compiler-agnostic: `clang-format`/`clangd` parse with their own
   frontend rather than invoking `gcc`/`clang` to build, so this works
   identically for gcc-built projects.

**Testing**: `smoketest.bats` gained mode-activation checks for
`.c`/`.cpp`/`.h`/`.mm`/`CMakeLists.txt`, LSP-load checks for `c-mode` and
`cmake-mode`, localleader keybinding checks (`c-keybindings.el`'s
format-buffer binding; `cmake-keybindings.el`'s new `+cmake/configure`/
`+cmake/build` commands, invoking `cmake -B build -S .` / `cmake --build
build` via `compile` — later renamed from bare `cmake-configure`/`cmake-build`
to the `+cmake/` prefix, and later still joined by `+cmake/rebuild`/
`+cmake/clean`; see this file's entries below), and tool-version checks for
`clang`/`clangd`/`gcc`/
`g++`/`cmake`/`gdb`/`cmake-language-server`/`vcpkg`/`conan` (40 total
`@test` cases now, up from 25). A manual debug project
(`flight-tests/c/`: `main.c`/`greet.c`/`greet.h` behind a small
`CMakeLists.txt`) was used for live container testing of both bugs above
before they were confirmed fixed via `smoketest.bats`. Both fixes and all
Dockerfile/`packages.el`-adjacent additions applied to the x86_64 tree in
lockstep, matching this project's established convention.

**Outstanding at the time this entry was first written**: the debugger half
of "full support" looked unwired. That assumption was wrong — corrected
immediately below, same day. Not yet committed to git either; these
changes (both trees) are still sitting as uncommitted working-tree
modifications.

---

#### Follow-up, same day: C debugger support was already fully wired

Went looking for how to wire `gdb` into the IDE (the gap noted just above)
and found there was nothing left to do. The original project plan (this
file's own "Language stack decisions" section, written 2026-05-06) says
"Debugger: `gdb` via dap-mode" — but that's stale: Doom's `:tools debugger`
module doesn't use `dap-mode`/`dap-utils`/vsix-downloaded VS Code extensions
at all anymore. Read the module's actual source at this project's pinned
Doom commit (`4e0dbb9`, `modules/tools/debugger/{config,packages}.el` and
`README.org`, fetched directly via `gh api` rather than assumed from
memory of an older Doom): it installs
[`dape`](https://github.com/svaante/dape) (pinned commit `48b3db3`), a
pure-Elisp DAP client with no VS Code extension dependency.

`dape`'s own source (`dape-configs`, also read directly rather than
assumed) ships a **built-in `gdb` template already covering
`c-mode`/`c-ts-mode`/`c++-mode`/`c++-ts-mode`** (plus Go and Hare), driven by
GDB's own native `--interpreter=dap` support (GDB ≥ 14.1, no separate
adapter binary, no Node.js, nothing to download) — exactly the `gdb`
binary already installed in this Dockerfile for the earlier C/CMake work.
Its `ensure` function runs `gdb --version` and throws `user-error` below
14.1; checked the actual apt-resolved version against the real archive
index rather than assuming — resolute/arm64 ships `gdb` 17.1-2ubuntu1,
noble/amd64 ships 15.0.50, both comfortably clear.

Separately, `:config (default +bindings)` (also already enabled in
`init.el`, present since project start) turned out to already bind a full
`SPC d ...` global prefix to every `dape` command that exists —
start/pause/continue/next/step-in/step-out/restart, breakpoint
toggle/log/expression/hits/remove-all, thread/stack select, watch,
evaluate, disconnect, quit — read directly from Doom's
`modules/config/default/+evil-bindings.el` at the pinned commit rather
than assumed present. `+debugger/start` (bound to `SPC d d` and also `SPC
o d`) is a plain `defalias` for `dape` itself.

Net result: no Dockerfile change, no `config.el`/`init.el` `:lang`/`:tools`
change, no new keybinding file — every piece (module, package, gdb binary,
global keybindings) was already in place before this session started.
Only one real fix made: `init.el`'s `(debugger +lsp)` dropped the stray
`+lsp` flag — the module's own `README.org` states "This module has no
flags," so the flag was inert dead syntax, not a meaningful toggle.

Added `smoketest.bats` coverage to turn this finding into a regression
guard rather than leaving it as an unverified read of upstream source: a
`gdb --version` major-version floor check (`>= 14`), a check that
`dape-configs`' `gdb` entry's `modes` list actually contains `c-mode` and
`c++-mode`, and a check that `SPC d d` resolves to `dape` in a `c-mode`
buffer. 43 `@test` cases now (was 40).

**Not verified**: an actual live debug session (compile with `-g`, `SPC d
d`, select the `gdb` config, hit a breakpoint) was not run end-to-end —
this environment has no docker/container access, same limitation noted
throughout this log. The smoketest additions confirm every piece is
correctly *wired*, not that a real GDB DAP handshake succeeds inside the
container; that's the one thing still worth Josiah confirming live.

---

#### `cmake-keybindings.el`: rebuild/delete-build bindings, then a style-guide pass

Josiah noticed `+cmake/build`'s incremental Make cache was hiding a
compiler warning (an unused variable) during flight-test iteration — the
prompting incident. Added two more localleader commands alongside the
existing configure/build pair: `SPC m b r` (`cmake --build build
--clean-first`, forces every file to recompile) and `SPC m b d` (`rm -rf
build`, full teardown — distinct from `--clean-first`, which only clears
compiled objects via the underlying build tool and leaves `CMakeCache.txt`
and the rest of the generated build system in place).

Josiah then asked for a review of this file (and the day's other changes)
against `ELISP-STYLE-GUIDE.md`/`ELISP-ARCHITECTURE-GUIDE.md`/
`DOOM-EMACS-GUIDE.md`, DRY, and general Doom/elisp convention. Two real
findings survived scrutiny, both fixed:

1. **Naming.** The original `cmake-configure`/`cmake-build` (and the two
   just added, matching that existing local pattern) were bare `cmake-*`
   names with no project namespace — a direct violation of this file's own
   `ELISP-STYLE-GUIDE.md` §3.2 ("every top-level symbol gets a prefix"),
   and inconsistent with the Doom-idiomatic `+module/name` convention
   already used elsewhere in this exact project (`go-keybindings.el`'s
   `+go/playground-yank`). Renamed to `+cmake/configure`, `+cmake/build`,
   `+cmake/rebuild`, `+cmake/clean`.

2. **Project-root anchoring.** All four commands ran `compile` against
   whatever `default-directory` happened to be — correct only when
   invoked from a buffer visiting the *top-level* `CMakeLists.txt`. A
   nested subdirectory `CMakeLists.txt` (an `add_subdirectory()` target)
   would build or `rm -rf` a `build/` in the wrong place. The first fix
   considered — `projectile-project-root` — was checked against this
   project's own `flight-tests/c/` before adopting it, and turned out to
   be actively wrong: that directory has no `.git` of its own, so
   `projectile-project-root` resolves to the *outer* `docker-emacs` repo
   root (no top-level `CMakeLists.txt` there at all), which would make
   `+cmake/clean`'s `rm -rf build` run with a far larger and wrong blast
   radius than the bug being fixed. Wrote `+cmake--root` instead: walks
   upward via `locate-dominating-file` past every nested `CMakeLists.txt`
   until no further ancestor has one, landing on the outermost project
   directory with no VCS dependency at all. All four commands now
   `let`-bind `default-directory` to `(+cmake--root)` around the `compile`
   call.

`smoketest.bats`'s keybinding-resolution test updated to match the
renamed symbols and now checks all four bindings (was two); still 43
`@test` cases (renames don't add tests). Also caught and fixed, while
reviewing: the x86_64 tree's copy of that same test had silently fallen
out of lockstep — it still only checked configure/build even after the
aarch64 tree gained rebuild/clean coverage in the debugger-review pass
above. Both trees now match exactly.

---

#### Docker and Podman support: bridge the host's engines, don't run a second one

Motivated by the FaradAI sandbox project, which manages its own containers
on the host. `docker`/`podman` were both entirely absent before this (no
`:tools docker` customization beyond the bare module, no podman anywhere).

**Design decision, made explicit before any code**: don't install a second
`dockerd`/podman storage backend inside this image at all. Container
image/volume storage is often many GB; running an independent engine
inside the IDE container would mean duplicating that storage rather than
sharing it. Instead, install only the **client** binaries (`docker.io`,
`podman` — both confirmed present in `universe` on both distros via the
real archive index, same verification standard as every other package
here: `docker.io` 29.1.3 on resolute/arm64, 24.0.7 on noble/amd64; `podman`
5.7.0 on resolute/arm64, 4.9.3 on noble/amd64 — versions differ across
distros and were left unpinned, matching how `clang`/`cmake`/`gdb` are
already handled) and bridge each client to the **host's** real engine over
its API socket, exactly the way `run.sh` already bridges Nix.

**Chose not to reuse the Nix bridge's approach.** That bridge exists
because a Nix store is already a portable, content-addressed artifact —
sharing it avoids a second copy of the *same* reproducible thing, and
needed real complexity to pull off (`ldd`-based library rediscovery every
launch, a `LD_LIBRARY_PATH`-scoped wrapper script, Fedora-vs-Ubuntu ABI
reconciliation). Docker and Podman don't need any of that: both engines
expose a documented, purpose-built remote API over a Unix socket
specifically so a thin client elsewhere can talk to them — a real
client/server boundary, not a filesystem store being creatively
relocated. Bridging the socket is the intended, supported way to do this,
not a workaround.

**Docker**: rootful, single system-wide `docker.service`, socket at the
fixed path `/var/run/docker.sock`, owned `root:docker` with group-rw
permissions (confirmed against this host directly rather than assumed).
Bind-mounted at the identical path — the Docker CLI's own default lookup
path, so no `DOCKER_HOST` env var is needed at all. The socket's group
ownership is the one real wrinkle: the container's runtime user needs
supplementary membership in a group matching that GID to access it
without root. Resolved with `docker run --group-add
"$(stat -c '%g' /var/run/docker.sock)"` at container-start time (`run.sh`)
rather than baking a specific GID into the image — the GID can differ
per host, and this is Docker's own documented pattern for exactly this
situation (the standard "mount the docker socket" DooD — Docker-outside-
of-Docker — approach used by most CI runners).

**Podman**: rootless, per-user `podman.socket` (a systemd *user* unit,
confirmed **not enabled by default** even though `podman` itself was
already installed on this host — `systemctl --user enable --now
podman.socket` was required and run directly against this host as part of
this session, since nothing works without it). Socket lives at
`$XDG_RUNTIME_DIR/podman/podman.sock`, owned directly by the invoking
user — no group trick needed, unlike Docker's rootful model. On the
aarch64 port specifically, `run.sh` already bind-mounts the *entire*
`XDG_RUNTIME_DIR` unconditionally (for Wayland), so the socket file
requires no additional `-v` at all once the host service is active — only
a `CONTAINER_HOST` env var pointing at it. **Podman's remote mode is not
optional the way it might look**: unlike the Docker CLI (always a thin
client, no other mode exists), the `podman` CLI defaults to managing
*local* storage directly whenever no `CONTAINER_HOST`/`--remote` is set —
with no local podman storage configured in this image on purpose, an
unset `CONTAINER_HOST` wouldn't fail loudly, it would silently start
building a redundant, broken local store inside the container instead of
ever reaching the host. Confirmed this distinction directly rather than
assuming Podman's API-socket behavior mirrors Docker's.

**`x86_64` port needed one adjustment aarch64 didn't**: that port's
`run.sh` has no unconditional `XDG_RUNTIME_DIR` mount at all (X11/`DISPLAY`
there, not Wayland), so the podman socket is bind-mounted explicitly by
its own specific path rather than riding along on a broader existing
mount. Both ports gained a `MOUNT_HOST_DOCKER`/`MOUNT_HOST_PODMAN` escape
hatch each (default on), mirroring `MOUNT_HOST_NIX`'s existing shape, plus
an informational `stderr` warning when either socket is missing —
deliberately not silent like the Nix mount's bare `if`, since "you forgot
to `systemctl --user enable podman.socket`" is an easy, easy-to-miss trap
worth surfacing at container-launch time rather than as a confusing error
from inside Emacs later.

**Doom/config.el side turned out to need almost nothing.** `dockerfile-mode`
(from the already-enabled `:tools docker` module) already matches
`Containerfile` in its own `auto-mode-alist` entry — confirmed directly
from source rather than assumed, so no new mode-alist wiring was needed
for Podman's preferred naming. `docker.el`'s `M-x docker` tabulated
management UI is already bound to `SPC o D` by Doom's own `:config default`
the moment `:tools docker` is enabled — also confirmed directly from
`+evil-bindings.el` rather than assumed, so no new binding was needed to
launch it either. The one real gap: `docker.el` only targets **one**
backend at a time via the `docker-command` variable (default `"docker"`,
left untouched), and there's no built-in way to view both docker and
podman through the same UI simultaneously — so the only new elisp
written is a small toggle, `docker-keybindings.el`'s `+docker/toggle-engine`
(`SPC o c`, flips `docker-command` between `"docker"`/`"podman"`). Checked
the full `SPC o` ("open") prefix-map in `+evil-bindings.el` directly before
picking `"c"` — `"e"`/`"E"` are already claimed by eshell (also enabled in
this project), which a guess would have silently collided with.

**Testing**: `smoketest.bats` gained a `docker --version`/`podman
--version` install check, a check that `SPC o D` resolves to `docker`, and
a check that `SPC o c` actually flips `docker-command` from `"docker"` to
`"podman"` when invoked. 46 `@test` cases now (was 43). The actual
socket-bridge behavior (whether the in-container `docker ps`/`podman ps`
really reaches the host's containers) can't be exercised by the bare
`bats smoketest.bats` invocation — same limitation as Nix's live
functionality, which also only gets a version/package-existence check
here and its real behavior verified via `nix-smoketest.bats` under
`run.sh`'s actual mounts. Not yet verified end-to-end against a live
rebuilt image — the actual `docker build` + `run.sh` cycle wasn't run
this session, only the host prerequisites (package availability, socket
paths/permissions, `podman.socket` enablement) were checked directly
against this host; pending Josiah's rebuild.

---

#### Bug: `SPC m e b` on `run.sh` failed with `/bin/sh: [[: not found`

Rebuilt image confirmed the docker/podman bridge works (`SPC o D` showed
real host containers). Separately, Josiah hit `sh-execute-region`
("Execute buffer", `SPC m e b`) failing on `run.sh` itself with `/bin/sh:
9: [[: not found` — a dash-only failure, not a bash one, even though
`run.sh` is `#!/usr/bin/env bash` and its modeline correctly showed the
bash dialect.

Root cause isolated by reading `sh-script.el` directly (installed source,
not assumed): `sh-execute-region`'s docstring says plainly "The executed
subshell is `sh-shell-file`" — but `sh-set-shell` only *updates*
`sh-shell-file` when called with a non-nil `insert-flag` (its third arg),
which happens only when a shebang line is being interactively
rewritten. The automatic dialect detection that runs for every
`sh-mode`/`bash-mode`/`zsh-mode`/`ksh-mode` buffer calls exactly
`(sh-set-shell (sh--guess-shell) nil nil)` — `insert-flag` nil — so
`sh-shell-file` never gets touched and stays at its global default
(`/bin/sh`, i.e. dash on this image) regardless of what `sh-shell` was
correctly detected as. `sh-shell` itself *is* reliably correct (confirmed
`sh--guess-shell` reads the buffer's own shebang line directly) — this is
purely a `sh-shell-file`-never-synced bug, present in vanilla
`sh-script.el` itself, not something introduced by this project's own
config. It would have affected `SPC m e e`/`SPC m e b` for **any**
bash-only script in this project (including files opened through this
project's own `bash-mode`/`zsh-mode`/`ksh-mode`, since those also call
`sh-set-shell` with a bare single argument) — just never actually
exercised until now, since the existing smoketest only checks that these
keybindings *resolve* to the right function, not that invoking them
actually executes correctly.

Fixed at the root in `shell-config.el`: `+shell--sync-shell-file`, hooked
onto `sh-mode-hook` (which fires for `bash-mode`/`zsh-mode`/`ksh-mode`
too, since they derive from `sh-mode` and Emacs runs all ancestor mode
hooks on activation), sets buffer-local `sh-shell-file` to
`(symbol-name sh-shell)` — mirroring the value that's already correctly
detected rather than reimplementing detection. Confirmed hook ordering is
safe by reading `sh-mode`'s own body directly: `(sh-set-shell
(sh--guess-shell) nil nil)` runs as part of the mode's own setup, which
completes before `run-mode-hooks` fires, so `sh-shell` is always already
correct by the time this hook runs.

**Testing**: added a `test-shebang.sh` fixture (`#!/usr/bin/env bash`,
deliberately no `.bash` extension, to exercise plain `sh-mode`'s shebang-
only detection path rather than this project's own extension-driven
`bash-mode`) and a test asserting both `sh-shell` and `sh-shell-file`
report `"bash"` after opening it. 47 `@test` cases now (was 46). Confirmed
via `emacs-lisp-mode`'s `check-parens` (not `fundamental-mode`'s — a
first attempt there false-flagged on ordinary apostrophes in comments,
since `fundamental-mode` has no syntax table telling it `'` isn't a
string delimiter) that `shell-config.el` still parses cleanly in both
ports. Not yet verified live against a rebuilt image; pending Josiah's
rebuild.

---

#### `run.sh`: inject the host's environment (not its dotfiles)

Prompted by the `sh-shell-file` bug above: Josiah's real question was
broader — for a script exercised via Emacs keybindings/M-x
(`sh-execute-region`, `compile`, `async-shell-command`) to behave the way
it would on the real host, doesn't the container need pieces of the
host's environment (his examples: `SSH_AUTH_SOCK`, `USER`, `HOME`, as
things he assumed came from `.bashrc`)?

First pass at this (mounting `.bashrc`/`.zshrc`/nushell dotfiles,
mirroring the existing `.gitconfig`/`.ssh` read-only mount pattern) turned
out to be solving a different problem than the one being asked. Checked
directly against this host rather than assumed: `HOME`/`USER` are not set
by any dotfile at all (grepped `.bashrc`/`.profile`/`.zshrc`/`.zshenv`/
`.zprofile` — zero exports; `loginctl` confirms these come from the
login/session layer, before any rc file runs). `SSH_AUTH_SOCK` genuinely
*is* shell-managed here (the systemd `ssh-agent.socket` unit is loaded
but inactive; the real agent socket lives at a path referenced directly
in `.zshrc`'s tmux-agent-reuse logic) — but that distinction doesn't
matter for the actual question, because `sh-execute-region`/`compile`
are **non-interactive** invocations, and non-interactive shells don't
source `.bashrc`/`.zshrc` even on the real host. Mounting the dotfiles
wouldn't have reached this case at all, regardless of which variables
happen to live in them on this particular machine.

Reframed once Josiah named the actual point explicitly: this container's
job is a reproducible, stable *tooling* environment, not a sandbox — so
the fix isn't per-variable archaeology (`.bashrc` vs login vs systemd
unit), it's capturing the calling shell's already-fully-resolved
environment (already dotfile-sourced, since `run.sh` itself always runs
inside an interactive host shell) and threading it straight into the
container as `-e` flags at the one point the boundary actually is —
container launch — rather than trying to re-derive it inside the
container per shell dialect.

**The one real tension, and it's the interesting part**: blind
wholesale injection would work against the container's own stated
purpose. `PATH`/`LD_LIBRARY_PATH`/`MANPATH`/`PYTHONPATH` describe *how to
find binaries*; overriding them with the host's own values would
reintroduce exactly the version drift this image exists to prevent —
trading fidelity to the host's *scripts* for breaking fidelity to the
image's own *toolchain*. So the design excludes those, plus anything
this script already bridges deliberately to a **different** value than
the raw host one (`SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`,
`GDK_BACKEND`, `DISPLAY` — a blanket pass-through would otherwise race
against the specific remapping already in place for each), `HOME`/`USER`
(already correct by construction — the container's own user is built at
image-build time to mirror the host username), and shell-instance-
mechanical variables that are either meaningless or actively wrong
carried into a different process/directory (`PWD`, `OLDPWD`, `SHLVL`,
`TERM`, `_`).

Implementation: `env -0` (NUL-separated, safe against embedded newlines
in values) piped through a `while` loop matching each key against a
regex exclusion list, building a `host_env` array of `-e KEY=value`
pairs exactly like every other conditional mount block in this file.
`INJECT_HOST_ENV=0` disables it entirely, matching the
`MOUNT_HOST_NIX`/`MOUNT_HOST_DOCKER`/`MOUNT_HOST_PODMAN` escape-hatch
convention already established here.

**Explicitly out of scope, and worth being precise about why**: this
covers *variables* only. Aliases and shell functions aren't part of the
process environment at all (bash can export functions via a special
encoding; zsh has no equivalent mechanism), so neither survives this
mechanism regardless — they only exist if a real interactive shell
actually sources the rc file, which is a `vterm`-opened-a-real-shell
concern, genuinely separate from the M-x/keybinding-execution problem
this solves. Josiah's own plan for that gap: a separate git-pullable
library of Bash/Zsh/Nushell functions, versioned and cloned in as a
dependency rather than baked into image config — reasonable, and not
something this session needed to build.

**Tested standalone** (not yet inside a rebuilt container): ran the
capture loop directly against this host's real shell environment — 83 of
166 total variables passed the exclusion filter; confirmed by name that
`PATH`, `HOME`, `USER`, `SSH_AUTH_SOCK`, `XDG_RUNTIME_DIR`, and `TERM` are
all correctly absent from the captured set. Not yet verified end-to-end
against a live rebuild; pending Josiah's rebuild.

---

#### Bug: `logic-ide/run.sh`, run from inside systems-ide, failed to mount `/ssh-agent`

Rebuild confirmed working (docker/podman bridge, cmake bindings). Then
Josiah tried the exact cross-project sanity check suggested earlier —
opening `logic-ide` from inside systems-ide and using the new docker
bridge to build/run *its* container from there — and hit `docker: Error
response from daemon: ... error mounting "/ssh-agent" to rootfs at
"/ssh-agent": ... not a directory`.

First hypothesis (transient: a stale `SSH_AUTH_SOCK` from `.zshrc`'s
tmux-agent-reuse logic, since a container was already confirmed running
fine) was wrong — Josiah corrected it: the systems-ide container was up
because it's the IDE session itself; the error was live inside *that*
session's own Emacs, from trying to launch logic-ide's container from
within it. That reframing pointed straight at the real mechanism.

**Root cause**: this file's `ssh_mounts` remaps `SSH_AUTH_SOCK` to a
fixed, container-local `/ssh-agent` path — a convention this project
established for mercury-ide/logic-ide before systems-ide ever bridged
`docker.sock`, i.e. before "launch a nested sibling container from
inside this one" was a scenario that existed at all. A `docker run`
issued from *inside* a container via a bridged `docker.sock` is still
executed by the **host's** real daemon — that's what the bridge means —
and the daemon resolves bind-mount source paths against the **host**
filesystem, not the calling container's. `logic-ide/run.sh` (unmodified,
using the exact same remap-to-`/ssh-agent` pattern) reads `SSH_AUTH_SOCK`
from whatever environment it's invoked in; from inside systems-ide, that
value was the remapped `/ssh-agent`, which is meaningless on the actual
host — the one filesystem the daemon actually checks.

**Confirmed live, not just reasoned about**, using `docker:cli` as a
disposable stand-in for "systems-ide" and `alpine` as a stand-in for
"logic-ide," reproducing the exact nesting shape (outer container's own
shell reads its own `$SSH_AUTH_SOCK` and constructs the inner `docker
run` itself, rather than expanding the variable once from outside):
- **Old pattern** (`-e SSH_AUTH_SOCK=/ssh-agent -v
  "${SSH_AUTH_SOCK}:/ssh-agent"`): the inner container's `/ssh-agent`
  came back as an **empty directory**, not a socket — silently broken,
  not even a loud error in this exact repro. Worse: it left a stray
  `root:root` directory at `/ssh-agent` on the **actual host root
  filesystem**, created by Docker's bind-mount auto-creation logic when
  the source path doesn't exist there. That residue is a plausible
  explanation for why the real failure surfaced as a loud OCI "not a
  directory" error rather than this repro's silent empty directory —
  once `/ssh-agent` exists on the host from an earlier attempt, a later
  attempt's mount resolution can conflict with it differently. (This
  stray directory needs `sudo rmdir /ssh-agent` on the host — outside
  what this session could clean up itself, no sudo access here.)
- **New pattern** (`-e SSH_AUTH_SOCK -v
  "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}"`, i.e. don't remap at all): the
  inner container's `/ssh-agent` came back as the real socket
  (`srw-------`), identical to a direct host launch.

**Fix**: `ssh_mounts` no longer remaps to `/ssh-agent` — it forwards
`SSH_AUTH_SOCK` at its real, identical host path, matching the "same
path in the container as on the host" convention every *other* bridge in
this file already follows (Nix, `XDG_RUNTIME_DIR`, `docker.sock`,
`Development/personal`). `/ssh-agent` was the one exception, and it's
the one bridge that had to compose with a nested invocation — not a
coincidence. This composes correctly with `logic-ide/run.sh` (and any
future project's `run.sh`) completely unmodified, since they just read
whatever real path `$SSH_AUTH_SOCK` already holds.

**Scope**: this is aarch64-only. x86_64's `run.sh` has no `ssh_mounts`
block at all — SSH forwarding was never wired up there, a separate,
pre-existing gap, not something this session's changes touched or
regressed. `logic-ide/run.sh`'s own remap-to-`/ssh-agent` was left
as-is: it's only a problem for whichever container is the one bridging
`docker.sock` and launching a nested sibling *from inside itself*, which
is systems-ide's role here, not logic-ide's — fixing the one script that
actually needs to compose with nesting is the root-cause fix, not
propagating the same change everywhere on principle.

---

#### Lua added as a seventh full-support language

Following a design discussion about scope: systems-ide isn't meant to be a
weaker `python-doom-emacs-ide`-style application-development IDE for
these languages, it's meant to be tailored to how a systems engineer
actually encounters them — isolated config/glue scripts embedded in
someone else's project, not a project of systems-ide's own. Lua gets
**full** support rather than the glue-script tier, though, matching the
original project plan's own reasoning (`README.md`'s new "Language
grouping philosophy" section, added this session, documents this split):
Lua configuration in window managers/Neovim/Redis/nginx is deep and
non-trivial enough that syntax-only would leave real value on the table.

**Doom's own `:lang lua +lsp` module does almost all of the work.**
Confirmed by reading it directly rather than assumed: it already wires
`lua-mode`'s interpreter detection (`\<lua(?:jit)?`), a REPL via
`set-repl-handler!` (reachable through `:tools eval`'s global `M-r` →
`+eval/buffer`, no custom binding needed), automatic LSP attachment via
the mode's own local-vars-hook once `+lsp` is enabled, and — per Doom's
own module README — format-on-save via StyLua through the already-active
`:editor format` module. `lua-keybindings.el` ended up needing almost no
custom code: one on-demand `lsp-format-buffer` binding (`SPC m f`),
matching `c-keybindings.el`'s exact same rationale (format-on-save
existing doesn't make an on-demand format command redundant), plus a
Commentary block documenting what Doom already provides for free.

**Two binaries needed manual installation, one interpreter from apt:**
- `lua5.4` (apt, both distros — `5.4.8-1build1` resolute/arm64,
  `5.4.6-3build2` noble/amd64). No bare `lua` symlink ships with Debian's
  versioned lua packages (deliberate, so multiple versions can coexist);
  `lua-mode`'s own interpreter-detection regex expects a bare `lua`/
  `luajit` name, so one is created explicitly
  (`ln -s /usr/bin/lua5.4 /usr/local/bin/lua`).
- `lua-language-server` 3.18.2, prebuilt Linux release binaries (arm64/
  x64), SHA256 computed directly from the downloaded artifacts rather
  than trusted from an upstream checksum file — neither this release nor
  StyLua's publishes one, unlike Go's/NFM's already-published hashes
  elsewhere in this Dockerfile. Ships as a whole directory tree (`bin/`,
  `locale/`, `main.lua`, ...), not a single relocatable binary — confirmed
  from the actual tarball listing before assuming a single-binary
  `install -m 755` copy (the pattern used for Go/NFM) would work; it
  wouldn't have, `bin/lua-language-server` depends on the sibling
  `main.lua`/`locale/` paths at fixed relative locations, so the whole
  archive is extracted intact to `/usr/local/lib/lua-language-server/`.
- `stylua` 2.5.2, prebuilt Linux release binary (aarch64/x86_64, non-musl
  variant matching Ubuntu's glibc rather than the musl build meant for
  Alpine). Single self-contained Rust binary — no Rust toolchain needed
  to install it, same reasoning as `nu`'s own prebuilt-tarball install.

**`lsp-clients-lua-language-server-bin` set explicitly in `config.el`**
rather than relying on `lsp-mode`'s own default install-directory
convention. Checked `lsp-mode`'s actual source for this rather than
trusting Doom's `:lang lua` module README, which describes an older
`$EMACSDIR/.local/etc/lsp/` convention — current `lsp-mode` (`clients/
lsp-lua.el`, `lsp-mode.el`) actually defaults to `$EMACSDIR/.cache/lsp/`,
a real, confirmed discrepancy between the README's documentation and the
actual dependency's current behavior. Rather than gamble on which
default is correct for the pinned Doom/lsp-mode commit this project
actually uses, the binary is installed to a fixed path this project
controls entirely (`/usr/local/lib/lua-language-server/bin/lua-language-
server`) and pointed at explicitly — the same "don't bet on a moving
default, be explicit" reasoning already applied to `lsp-auto-guess-root`
and `docker-command` elsewhere in this same file.

**Testing**: `smoketest.bats` gained a `test.lua` fixture, an install
check for all three tools (asserting the pinned `lua-language-server`/
`stylua` versions specifically, matching the regression-guard convention
already used for `gopls`/`dlv`/`golangci-lint`), `.lua` → `lua-mode`
activation, an LSP-load check, and the format-buffer keybinding
resolution check. 51 `@test` cases now (was 47). Confirmed every `.el`
file touched this session (`config.el`, `init.el`, `lua-keybindings.el`)
parses cleanly via `emacs-lisp-mode`'s `check-parens` — not
`fundamental-mode`'s, which produced false positives on ordinary
apostrophes earlier this same log for exactly this reason. Confirmed
`lua-keybindings.el` already had its Dockerfile `COPY` line (it's a
placeholder scaffolded at project start, unlike `docker-keybindings.el`
earlier this session, which was newly created and genuinely missing
one) — checked directly rather than assumed, after getting burned by
exactly that gap once already.

**Bug found on first real build attempt: `ln: Permission denied`** on the
`lua` symlink step. All three lua install `RUN` steps were placed after
`USER ${USERNAME}` (line 233) — this Dockerfile switches to the non-root
runtime user partway through, and everything after that point only has
write access within its own `$HOME`. `/usr/local/bin`/`/usr/local/lib`
are root-owned; the apt packages and the Go tarball earlier in this file
never hit this because they run *before* the `USER` switch, as root.
`vcpkg`/`conan`/`nupm`, added the same session as the C/CMake work,
already follow the correct pattern (installed under
`/home/${USERNAME}/...`) — the lua steps were the one exception, added
without checking where they'd land relative to that switch. Fixed by
moving all three installs under the runtime user's own `~/.local/`
(`~/.local/bin/lua`, `~/.local/bin/stylua`, `~/.local/lib/lua-language-
server/`) — `~/.local/bin` was already on `PATH` (see the `ENV PATH` line
earlier in this file), so no new `PATH` entry was needed. `config.el`'s
`lsp-clients-lua-language-server-bin` and `smoketest.bats`'s version
check both updated to match, using `(expand-file-name "~/...")`/`$HOME`
respectively rather than a literal username, so neither depends on the
runtime user's exact name. Not yet verified end-to-end against a
rebuild with this fix in place; pending Josiah's next rebuild attempt.

---

#### Python, Ruby, and JavaScript added as a glue-script tier — LSP on, project tooling off

Design discussion landed on a real distinction from the original plan:
these three (plus the still-unbuilt Ruby/Perl/Fish/Assembly batch) were
originally slated "syntax only, no LSP" — but LSP's actual value doesn't
depend on having a project. Modern language servers handle a lone file in
an inferred single-file project just fine for anything within the
standard library, which is most of what a systems-context script actually
is (Ruby for Chef recipes, not Rails; Python for WM/DE config scripting
and one-off Fabric tasks, not framework development). What breaks without
a project is narrower than "everything" — just resolution of actual
third-party imports. So: LSP on for all three, but deliberately **no**
pip/poetry/conda, no bundler/rvm/rbenv/chruby, no node_modules-based
tooling — scoped to editing/linting isolated scripts, never to developing
applications in these languages (a job this project already has a
separate dedicated IDE for, per `python-doom-emacs-ide` in the root
`README.md`'s image table — `README.md`'s new "Language grouping
philosophy" section, written this session, documents the full
reasoning).

Linters and formatters were explicitly back in scope this time (a
correction from the original syntax-only plan, which had neither) —
Josiah's framing: "style and discipline are always important even for
just scripting."

**Python**: `(python +lsp +pyright)`. `pyright` chosen over the newer
`ty` (also supported by lsp-mode via `clients/lsp-python-ty.el`, and
listed first/"recommended" in Doom's own module README) — `ty-ls` is
registered `:add-on? t`, meaning it runs *alongside* a primary client
rather than replacing one, so it wouldn't have been sufficient alone
regardless; `pyright` is the long-established, single, well-supported
choice, matching this project's repeated preference for one mature tool
over a newer one still establishing itself (clangd over ccls, `ty` not
pursued for the same reason). Installed via `npm install -g
pyright@1.1.411`, matching `bash-language-server`'s existing install
shape exactly.

`ruff` handles both linting (flycheck's built-in `python-ruff` checker —
confirmed directly from flycheck's own source that this checker's
`--config` flag uses flycheck's `config-file` cell type, meaning it's
simply omitted when no `pyproject.toml`/`ruff.toml` is found rather than
erroring, so it's genuinely zero-config-capable) and formatting
(overriding apheleia's own default of `black` for `python-mode`).
Considered installing `black` instead (apheleia's default, zero override
needed) — Josiah's call after discussing the tradeoff: `ruff format` is
explicitly built to match Black's own output, so the actual formatted
result is nearly identical either way; the reason to prefer `ruff` is
purely that it's already required for linting, so using it for both
avoids installing a second, unrelated tool via `pipx` for formatting
alone. `ruff format`'s configurability was checked directly against its
live JSON schema rather than assumed (`quote-style`, `skip-magic-trailing-
comma`, `indent-style`, `indent-width`, `line-ending`, `docstring-code-
format`, `preview` are the real, current knobs) — genuinely more
configurable than Black, though still deliberately opinionated by design,
not sprawling like Prettier/clang-format.

Ruff's own docs were checked (not assumed) for a **user-level config**
mechanism, since the whole point here is style preferences applying to a
lone script with no project file of its own: `${config_dir}/ruff/
pyproject.toml` (on Linux, XDG-style, via the `etcetera` crate's base
strategy) is used whenever no project-level config is found in the
directory hierarchy — and a real project's own config still takes
precedence automatically if one ever exists. Baked in as
`ruff-pyproject.toml`, `COPY`'d to exactly that path, encoding Josiah's
actual style decisions from this session's discussion: 2-space indents,
LF line endings, docstring code formatting on, no preview features
("systems programmers should optimize for stability"), and — after
initially discussing disabling it — magic trailing comma left **on**
("if I want everything on one line, I can just delete that comma, and
the pattern then is consistent").

**Ruby**: `(ruby +lsp)`, no `+rails`/`+rvm`/`+rbenv`/`+chruby`. `ruby-lsp`
(Shopify's, the actively-maintained modern choice) over `solargraph` —
confirmed via `lsp-mode`'s own `lsp-ruby-lsp.el` that `lsp-ruby-lsp-use-
bundler` defaults to `nil`, so it runs as plain `ruby-lsp` with no
Gemfile/bundler involvement at all, matching this tier's scope exactly;
solargraph isn't installed, so there's no ambiguity between the two for
lsp-mode to resolve. Both `ruby-lsp` and `rubocop` installed via global
`gem install --no-document` (no bundler). `rubocop` handles both linting
(flycheck's built-in `ruby-rubocop` checker, same zero-config-friendly
`config-file`-cell pattern as `python-ruff`) and formatting (`rubocop -a`,
overriding apheleia's own default of `prettier-ruby` for `ruby-mode` —
checked directly and confirmed apheleia's default surprisingly pulls in
an npm-based `@prettier/plugin-ruby`, a whole separate JS toolchain, just
to format Ruby; `rubocop` avoids that entirely, one Ruby-native tool
already needed for linting doing both jobs).

**JavaScript**: `(javascript +lsp)`, wired to `typescript-language-server`
+ its `typescript` peer (not `deno`, the module's other supported
server), both via npm, matching the existing `bash-language-server`
install shape. Linting deliberately uses `oxlint`, not `eslint` — checked
flycheck's own two checker definitions directly: `javascript-eslint` has
a dedicated `flycheck--eslint-handle-suspicious` code path specifically
for the "no config found" case (confirming this is a known, expected
friction point, not an edge case), while `javascript-oxlint`'s `:command`
is just `oxlint --format checkstyle <file>` with no config-file handling
at all — genuinely zero-config, the same role `ruff`/`rubocop` play for
their languages. `eslint` isn't installed, so there's no checker
ambiguity for flycheck to resolve. Formatting uses apheleia's own
existing default (`prettier`) for `js-mode`, unchanged — no override
needed, unlike Python/Ruby.

**Design inconsistency found and *not* fixed, on purpose, out of
scope**: `c-keybindings.el`/`lua-keybindings.el`'s on-demand format
binding calls `lsp-format-buffer` (the LSP server's own formatting
capability), while `python-keybindings.el`/`ruby-keybindings.el`/
`javascript-keybindings.el` (written this session) call
`apheleia-format-buffer` directly instead. This isn't arbitrary: `pyright`
does not implement LSP-level document formatting at all (confirmed by the
fact that `python-mode` needs its own independent apheleia formatter
mapping regardless of LSP server choice — if pyright formatted, this
wouldn't be necessary), so `lsp-format-buffer` would have been a silent
no-op for Python specifically; using `apheleia-format-buffer` uniformly
for the three new languages also guarantees the on-demand and on-save
paths always use the *identical* formatter, which isn't strictly
guaranteed by the older `lsp-format-buffer` pattern (clangd/lua-language-
server happen to agree with clang-format/stylua's output, but that's
coincidence, not a guarantee). Reconciling `c-keybindings.el`/`lua-
keybindings.el` to the same `apheleia-format-buffer` pattern is a
reasonable future cleanup, deliberately not done here to keep this
session's diff scoped to what was actually asked for.

**Not independently re-verified this session, flagged as a reasonable
but unconfirmed assumption**: whether lsp-mode gracefully skips the
`ty-ls` add-on client (registered by `lsp-mode` alongside `pyright`,
`:add-on? t`) when the `ty` binary isn't installed, versus erroring or
warning. Given `pyright`-without-`ty` is almost certainly the overwhelming
majority real-world lsp-mode Python setup (`ty` is new), graceful
degradation here is very likely already the case — just not something
this session directly tested.

**Testing**: `smoketest.bats` gained fixtures (`test.py`/`test.rb`/
`test.js`), tool-install checks for all nine new binaries/packages
(asserting pinned versions, matching the `gopls`/`dlv`/`golangci-lint`
regression-guard convention), mode-activation + LSP-load checks for all
three languages, format-buffer keybinding resolution checks, and a direct
check that `apheleia-mode-alist` actually resolves to `(ruff rubocop)`
for `(python-mode ruby-mode)` rather than trusting the `setf` calls
silently succeeded. 64 `@test` cases now (was 51). Every new/touched `.el`
file (`config.el`, `init.el`, `python-keybindings.el`, `ruby-
keybindings.el`, `javascript-keybindings.el`) confirmed parsing via
`emacs-lisp-mode`'s `check-parens`; every `.el` file in the directory
re-confirmed to have a matching Dockerfile `COPY` line, after the
`docker-keybindings.el` gap earlier this session made that check
standard practice going forward. Not yet verified end-to-end against a
live rebuild; pending Josiah's build (in progress as this entry is being
written — x86_64 mirror to follow while aarch64 builds).

#### Rust added as an eighth full-support language

Rust gets full IDE support (LSP + debugger), the same presumption already
made for Go, C/C++, Nix, Shell, Bats, Nushell, and Lua — not the
glue-script tier Python/Ruby/JavaScript/TypeScript get. `(rust +lsp)`
added to `init.el`.

**Toolchain**: rustup, not apt — pinned to `1.97.1` (checked live against
`https://static.rust-lang.org/dist/channel-rust-stable.toml` at write
time rather than assumed), `--profile minimal --no-modify-path` since
PATH is managed via Docker `ENV`, not shell rc files. `rust-analyzer`,
`rustfmt`, `clippy` are rustup *components*, not separate installs — they
land as proxy shims alongside `cargo`/`rustc` in `~/.cargo/bin`, so one
PATH entry covers the whole toolchain. Installed post-`USER` switch
(matches the ruff/stylua/vcpkg precedent — rustup's own design is a
per-user install, `~/.cargo`/`~/.rustup`, not a system-wide one like Go's
`/usr/local/go`).

**Major mode**: `.rs` files use `rustic-mode` (from the `rustic` package,
which Doom's `:lang rust +lsp` module pulls in for its cargo
integration), not plain `rust-mode` — confirmed by fetching Doom's own
`modules/lang/rust/config.el`/`packages.el` at this image's pinned
`DOOM_COMMIT` rather than assumed from current upstream (which has since
restructured its repos entirely — `doomemacs/doomemacs` 404s now,
redirects to `doomemacs/core`, and `:lang` modules moved out of the
monorepo; had to fetch `contents/modules/lang/rust?ref=<pinned-commit>`
specifically to see what this image's actual pinned Doom version ships).

**Keybindings — much thinner than go-keybindings.el, on purpose**:
Doom's own rust module already wires an extensive `rustic-mode-map`
localleader map directly in its package `:config` block (`SPC m b`
prefix: audit/build/bench/check/clippy/doc/doc-open/fmt/new/outdated/run;
`SPC m t a`/`SPC m t t` for cargo test) — go-keybindings.el had to hand-
build the equivalent because Go's own module leaves more to custom
REPL/playground glue. `rust-keybindings.el` only adds one binding, bare
`SPC m f` → `apheleia-format-buffer`, purely for cross-language muscle-
memory consistency with every other language here (Doom's own module
binds format to `SPC m b f` instead, reaching the same `rustfmt` via
`cargo fmt` rather than apheleia — not a gap, just a different key).
Wrapped in `after! rustic-mode` per the go-mode/nix-mode race-condition
fix already established this project (rustic's own bindings load lazily
on first `.rs` visit via its package `:config` block; an unwrapped `map!`
here would run at Doom config-load time instead, before that).

**Formatting**: apheleia's own default `apheleia-mode-alist` already
maps both `rustic-mode` and `rust-mode` to `rustfmt` — confirmed directly
against `apheleia-formatters.el` upstream rather than assumed (this is
exactly the kind of default that turned out to be *missing* for
`typescript-mode` earlier this session, so it was checked, not trusted).
No config.el override needed.

**Debugging — lldb, not gdb, and why**: researched directly against
dape's own source rather than guessed. dape's built-in `gdb` config's
`modes` list is `(c-mode c++-mode hare-mode ...)` — rust-mode is absent.
Its `lldb-dap`/`lldb-vscode` configs' shared `modes` list is `(c-mode
c++-mode rust-mode rust-ts-mode rustic-mode ...)` — dape's own
maintainers already treat Rust as an lldb language. Using lldb means
zero elisp config; gdb would have needed its `modes` list extended by
hand. Full reasoning (including that both debuggers are now equally
officially supported by rust-lang/rust's own pretty-printers, so that
wasn't the deciding factor) is in DECISIONLOG.md, along with a
deliberate decision *not* to also flip C/C++ from gdb to lldb — gdb
there is already installed, tested, and asserted by an existing
smoketest.bats case, and there's no concrete gdb-for-C problem motivating
a switch. Installing `lldb` for Rust does incidentally register its dape
configs for c-mode/c++-mode too (already in that same `modes` list) —
so C/C++ gets lldb as a free alternative in `SPC d d`'s menu regardless,
without any code change.

**Not installed, deliberately**: `cargo-audit`/`cargo-outdated` (optional
cargo subcommands Doom's module also wires bindings for) — not part of
the LSP+debugger scope, matching this image's existing precedent of
leaving some Doom-supported extras uninstalled (ccls, deno, solargraph,
eslint). Those two bindings will error if pressed; documented as expected
in both rust-keybindings.el and the flight-test.

**Testing**: `smoketest.bats` gained a `test.rs` fixture, a tool-install
check (`cargo`/`rust-analyzer`/`rustfmt`/`cargo-clippy`/`lldb-dap`,
pinned-version assertion for `cargo`), mode-activation + rust-analyzer-
connects checks, a dape `lldb-dap` config coverage check (mirroring the
existing gdb/c-mode one), and a localleader resolution check covering
both Doom's own cargo bindings and this file's added `SPC m f`. A real
two-file flight-test project (`flight-tests/rust/`: `Cargo.toml`,
`src/main.rs`, `src/counter.rs`) exercises cross-file go-to-definition,
`cargo test`, and a commented-out deliberate type error for diagnostics,
with a `rust-flight-test.md` checklist mirroring go-flight-test.md's
shape. `rust-keybindings.el`/`config.el`/`init.el` re-confirmed against
the load!/Dockerfile-COPY cross-check (standard practice since the
`typescript-keybindings.el` gap earlier this session, where `load!` was
wired but the `COPY` line was missed — `rust-keybindings.el` already had
its `COPY` line from its original stub state, confirmed before writing
any real content into it, so no gap this time).

**Not yet verified end-to-end against a live rebuild**: everything above
was checked statically (dape.el's real source, apheleia's real defaults,
Doom's rust module source fetched at the exact pinned commit, `lldb`/
`gdb` versions confirmed live in a throwaway `ubuntu:26.04` container)
rather than assumed, but none of it has been run against an actual
rebuilt image yet — rust-analyzer connecting, `SPC d d` actually hitting
a breakpoint via lldb-dap, and the keybindings resolving in a live daemon
all still need confirming once the image builds. x86_64 mirror applied
in lockstep while aarch64 builds.

#### Follow-up: live verification against the rebuilt aarch64 image found three bugs

Everything in the entry above was checked against real source, not
assumed — but static review still missed three bugs that only surfaced
once the image actually built and got exercised live (`docker exec` into
the built image, `emacsclient --eval` against a real daemon, the actual
flight-test fixture).

**Bug 1 — `SPC m f` silently dead.** `rust-keybindings.el` wrapped its one
binding in `(after! rustic-mode ...)`. `rustic-mode` is the *major-mode
symbol* the `rustic` package defines, not the feature it `provide`s —
`(featurep 'rustic)` is `t`, `(featurep 'rustic-mode)` is `nil` — so that
`after!` block never fired at all, silently (no error; it just never ran).
Doom's own cargo bindings (`SPC m b b`/`SPC m b r`/`SPC m t a`) resolved
fine since those load inside rustic's package `:config` block directly;
only this file's own addition was affected. Fixed: `after! rustic`.
Caught by literally pressing the key against a live buffer and comparing
`(key-binding (kbd "SPC m f"))` to the other three — the exact
`smoketest.bats` assertion already written for this, which is what
should have caught it pre-review; it's a good reminder the smoketest
still needs to actually *run* against a build, not just exist.

**Bug 2 — `:program "a.out"`, and it's not Rust-specific.** Live-testing
`SPC d d` produced `Cannot launch '.../target/debug/flight-test':
personality set failed` — traced to dape's own built-in `gdb`/`lldb-dap`/
`lldb-vscode` configs all hardcoding `:program "a.out"`, a leftover from
C's `cc foo.c` default output name. Compared against `dlv` (Go's
debugger): its `:program` is `"."`, since Go's tooling runs straight from
a source directory — no binary-path problem to have. lldb/gdb both need
an actual compiled-binary path, so there's no equivalent trick; it has to
be resolved per-project. This is a *shared* dape default, not something
either Doom or this repo's config had touched, and it affects C/C++'s
`gdb` config identically — nobody had actually pressed `SPC d d` against
the CMake-built C flight-test either, so that gap had been latent and
unverified the whole time C was claimed as "full support." Fixed with a
`:program` resolver function (dape evaluates function-valued config
entries with no arguments and substitutes the result): `cargo build
--message-format=json` for cargo projects (asks cargo directly for the
authoritative output path rather than guessing `target/debug/<crate-
name>`, which can differ from the `[[bin]]` name), and a `./build/`
single-executable scan for CMake projects (matching `+cmake--root`'s
existing convention in `cmake-keybindings.el`). This is genuinely cross-
language config, not Rust-specific, so it moved to its own new
`dape-config.el` (extracted out of `config.el`, `load!`'d, `COPY`'d in
the Dockerfile — same file/load!/COPY checklist as any new elisp file
here) rather than living in `rust-keybindings.el` or `c-keybindings.el`.
Verified: both resolver functions checked directly against real builds
(`+dape-cargo-program` → `target/debug/flight-test`; `+dape-cmake-program`
→ `build/ctest`), not just read from source.

**Bug 3 — lldb-server hangs launching any binary at all, on this
host/arch.** Fixing bug 2 got debugging further, but `SPC d d` then hung
instead of erroring. Isolated methodically rather than guessed at:
- Reproduced with raw `lldb` CLI, bypassing dape/DAP entirely — same hang.
- Reproduced against a CMake-built C binary too, not just Rust — ruling
  out anything Rust-specific.
- Tested under progressively looser container privilege: default (zero
  extra capabilities) → `--cap-add=SYS_PTRACE` → `--cap-add=SYS_PTRACE
  --security-opt seccomp=unconfined` → full `--privileged` (every
  capability, no seccomp, no confinement). The hang was identical at
  every level, which rules out a Docker capability/seccomp/SELinux
  restriction as the cause — `--privileged` is the ceiling; nothing left
  to grant.
- gdb, tested the same way, worked immediately at every privilege level
  including the container's unmodified default. It hits the same
  underlying `personality()` ASLR-disable restriction lldb does (a
  `warning: Error disabling address space randomization: Operation not
  permitted` in the default config) but treats it as non-fatal and
  proceeds, where lldb treats it as a hard launch failure.
- Root cause of the lldb-server hang itself not yet identified — this is
  now a separate, ongoing investigation (see DECISIONLOG.md's "Debugging:
  lldb-server hangs..." entry), independent of the Rust work.

Decision (fully reasoned in DECISIONLOG.md): flip c-mode/c++-mode/
rust-mode/rustic-mode/rust-ts-mode all onto `gdb` exclusively. Clear
`lldb-dap`/`lldb-vscode`'s `modes` entirely so `SPC d d` doesn't offer a
silently-hanging option for any language here. `lldb` stays installed
(small footprint; aarch64 lldb-server support may mature) but unoffered
until the hang is root-caused. This reopens and revises both of last
night's debugger DECISIONLOG entries — the reasoning in each was sound
given what was known at the time; the new information is that lldb
doesn't actually work on this host/arch at all, which neither entry had
access to.

**Verified live end-to-end after all three fixes**: `SPC d d` → select
`gdb` → breakpoint on `c.inc();` → launch → correct stop at
`flight_test::main` / `src/main.rs:17` → correct populated locals
(`message "Hello"`, `c` present) — the real dape → DAP → gdb flow, not a
simulated approximation of it. rust-analyzer hover, cross-file doc
resolution, and `textDocument/completion` (struct fields, inherent
methods, blanket-trait methods, postfix snippets) also confirmed live
against the actual flight-test fixture, not just read from lsp-mode's
source.

**Not yet done**: none of this has been repeated against the x86_64
tree's own build — the code changes were mirrored there, but the
lldb-hang finding and the gdb verification are aarch64-only so far (see
DECISIONLOG.md's caveat on that entry). The lldb-server hang itself
remains unresolved; actively being investigated further.

#### Follow-up, same day: the lldb hang was `DEBUGINFOD_URLS`, not the host/arch — reverted back to lldb for Rust

The gdb-flip above turned out to be solving the wrong problem. `strace`
(added to the image as a permanent apt package — routine enough to earn
for systems work generally, not just this one investigation) on a
hanging `lldb -b -o run -o quit` showed no `ptrace`/`personality`/`fork`
call anywhere near the hang — lldb was still inside `target create`,
parked in a socket poll loop on a TLS connection to
`debuginfod.ubuntu.com`. Ubuntu's `/etc/profile.d/debuginfod.sh` sets
`DEBUGINFOD_URLS` for every login shell; gdb explicitly prompts ("Enable
debuginfod for this session?") and respects a non-interactive "no" —
that's why gdb was never affected and why this looked, for a while, like
an lldb-vs-gdb difference in behavior rather than what it actually was.
lldb has no equivalent gate; it just tries the connection and blocks
indefinitely.

`DEBUGINFOD_URLS=""` fixed it completely: 0.2 seconds instead of a hang,
full correct program output, clean exit — confirmed via raw CLI, a live
daemon restart with the variable cleared, and the actual `SPC d d` ->
dape -> lldb-dap DAP flow (breakpoint hit at the correct line, and a
full accurate backtrace through Rust's runtime internals down to
`_start`, more detail than gdb's stack view had shown).

Fixed at the image level (`ENV DEBUGINFOD_URLS=""` in the Dockerfile, not
per-debugger-config — it isn't a debugger-specific setting). This
reverses this morning's gdb-flip entirely: `dape-config.el`'s `modes`
overrides are removed, `rust-keybindings.el`'s comments and
`rust-flight-test.md`'s Debug section are reverted back to lldb-dap.
Only the `:program` "a.out" resolver stays, since that fix was always
correct and unrelated to the debuginfod problem. Full reasoning
(including why the privilege-level testing this morning wasn't wasted
work — it correctly ruled out capabilities/seccomp/SELinux, it just
hadn't yet checked environment variables) is in DECISIONLOG.md.

Not yet done: x86_64 mirror applied (Dockerfile, dape-config.el,
rust-keybindings.el, flight-test doc, DECISIONLOG.md, strace) but not
independently verified there — same caveat as this morning's now-reverted
gdb-flip, just resolved in the opposite direction.

#### Same day, second follow-up: `DEBUGINFOD_URLS` wasn't the whole story — `personality set failed` came back

Rebuilt the image with the `DEBUGINFOD_URLS` fix above and tested against
the actual, unmodified `run.sh` (no extra Docker capabilities — none of
the `--cap-add`/`--security-opt` flags from earlier privilege-level
testing) — and hit `Cannot launch '.../flight-test': personality set
failed: Operation not permitted`, the exact error this whole
investigation started with. `DEBUGINFOD_URLS` was a real, necessary fix
for a real, separate bug, but it was never the *only* problem — it just
happened to be the first thing standing in the way once the earlier
`--privileged` test container was already bypassing the second problem
entirely, which made it invisible until testing against the real
container configuration.

Reproduced cleanly in a fresh daemon, in the exact zero-extra-capability
container `run.sh` launches: `lldb-dap` hits the same `personality()`
ASLR-disable denial gdb does (gdb just warns and proceeds; lldb-dap
treats it as fatal). Two dead ends before finding the real fix: neither
`~/.lldbinit`'s `settings set target.disable-aslr false` nor an
`initCommands` DAP launch argument doing the same actually prevented the
failure — both run too late, since lldb-dap's ASLR-disable happens inside
its own launch-request handling before either fires. The actual fix:
`:disableASLR nil`, lldb-dap's own dedicated DAP launch argument for
this, added to `dape-config.el` alongside the `:program` resolver.
Confirmed in the exact same zero-privilege container: clean launch,
correct breakpoint stop, full accurate backtrace — no `run.sh` changes,
no container capability/seccomp loosening, needed at all.

Net result: lldb debugging works correctly in this image's actual,
unmodified default container configuration, fixed by one Dockerfile `ENV`
line and one dape config key — not a security tradeoff of any kind.
DECISIONLOG.md's final entry on this now covers both causes together.
x86_64 mirror applied; still not independently verified there.

#### Open investigation, same day: lldb-dap runs straight past every breakpoint — a real dape/lldb-dap race condition, unresolved

**Checkpoint written mid-investigation** (in case of context compaction) — this
is not yet fixed. Status as of writing: a fresh breakpoint, correctly placed,
gets silently ignored; the program always runs to completion instead of
stopping. Confirmed via the actual `run.sh`-launched container
(`doom-systems-ide-aarch64`), which was still running and directly
inspectable via `emacsclient` — all diagnosis below happened live in that
real session, not a throwaway container.

**Ruled out, in order:**
1. Stale/persisted breakpoints (`dape-breakpoint-global-mode` persists across
   sessions) — found 3 real source breakpoints at 3 different lines (11, 17,
   22) left over from earlier testing tonight, all at genuinely valid
   executable-line locations. Cleared all, set exactly one fresh breakpoint —
   still ran straight through. Not the cause.
2. `run.sh`'s `INJECT_HOST_ENV` host-environment passthrough shadowing
   something — retested with `INJECT_HOST_ENV=0`. Still broken. Not the
   cause.
3. `DEBUGINFOD_URLS`/`personality()` (the two bugs fixed above) — confirmed
   fully resolved; no hang, no permission error, launch always completes
   cleanly and quickly. Unrelated to this new problem.

**Root cause, found via live JSON-RPC tracing**: `dape-connection` in this
dape version is an EIEIO class wrapping `jsonrpc.el`, but dape explicitly
disables jsonrpc's built-in events-buffer logging (`:size 0` in its
`-events-buffer-config`), so there's no out-of-the-box protocol log to read.
Worked around by live-advising `jsonrpc-connection-send` and
`jsonrpc--log-event` into a scratch buffer (`*my-dape-trace*`) via
`emacsclient --eval` against the user's live Emacs, then re-running the
launch. This revealed the actual request sequence:

```
id 1: initialize
id 2: launch          <-- sent immediately, right after initialize's response
id 3: setExceptionBreakpoints
id 4: setBreakpoints  <-- sent AFTER launch, too late
id 5: setFunctionBreakpoints
id 6: setDataBreakpoints
id 7: configurationDone
```

Reading `dape.el`'s actual source (`svaante/dape`, fetched directly from
GitHub) confirms this is a genuine **race condition in dape itself**, not a
config mistake:
- The `initialize` response handler sends `launch`/`attach`
  **unconditionally** unless `defer-launch-attach` is set — with no
  coordination to anything else.
- `setBreakpoints`/`setExceptionBreakpoints`/`setFunctionBreakpoints`/
  `setDataBreakpoints`/`configurationDone` only fire in response to a
  **separate, independent** `initialized` *event* the adapter sends
  whenever it decides it's ready — dape.el's `dape-handle-event` method for
  the `initialized` symbol.

These are two unsynchronized code paths. If the adapter emits `initialized`
slower than dape processes the `initialize` response (a timing race, not a
logic bug), `launch` wins and the program is already running before
breakpoints arrive. This also explains why it reproduces 100% reliably in
the user's real `run.sh` container but did *not* reproduce in this session's
earlier throwaway test containers (`rust-verify`, `rust-verify-cap2`) using
what should be identical commands — those containers are plain local Docker
storage with less I/O overhead than the real container's several bind
mounts (Nix store, Development/personal, ssh-agent, docker socket, etc.),
plausibly enough timing difference to flip which side of the race wins.

**`defer-launch-attach: t`** is dape's own documented, purpose-built
mechanism for exactly this situation (its docstring cites "GDB bug 32090"
as the origin) — gdb apparently doesn't need it here (works fine with the
default `nil`, presumably because gdb internally holds off actually running
until `configurationDone` regardless of when `launch` arrives, an
adapter-side behavior dape can't control). Setting it to `t` for
`lldb-dap`/`lldb-vscode` live (via the same `dape-configs` alist patch
pattern as the `:program`/`:disableASLR` fixes) did **not** fix it — it
caused a full stall instead: after `t` was set, a fresh launch sent only
`initialize` and then nothing else at all, not even `setBreakpoints`, for
at least 8+ seconds (well past when the untouched flow would have finished
setting breakpoints and running). This means the `initialized`-event
handler chain that should fire the setBreakpoints/configurationDone
sequence didn't fire either — not just that launch was withheld correctly.
Not yet understood why; this is the current open question.

**Diagnostic technique worth remembering**: `jsonrpc-connection-send`/
`jsonrpc--log-event` advice is the way to get real protocol traces out of
dape despite its events-buffer logging being disabled by default. Cleaned
up (advice removed, trace buffer killed, breakpoints/patches reverted) at
the point this checkpoint was written — the user's live session should be
back to a normal, un-instrumented state. `dape-config.el`'s
`:disableASLR`/`:program` fixes remain in place (still fully working); no
`defer-launch-attach` change has been committed to any file yet — that was
tested only as a live, uncommitted patch.

**GitHub issue search** (`svaante/dape`): no exact match found. Closest was
issue #151 ("lldb-dap runs my program but it doesn't stop at breakpoints,"
closed) — but that one's actual cause was missing `-g` debug info, which
doesn't apply here (this image's binaries demonstrably have full DWARF
info: hover, cross-file docs, and accurate multi-frame backtraces already
confirmed working earlier tonight). Issue #293 ("configurationDone request
sent despite adapter not supporting it," closed) is conceptually adjacent
— dape's maintainer acknowledged a real spec-compliance gap around
`configurationDone` there — but is a different specific bug (missing
`supportsConfigurationDoneRequest` capability check, not applicable since
lldb-dap's capabilities response does include
`:supportsConfigurationDoneRequest t`). This looks like a legitimate,
not-yet-reported dape/lldb-dap bug — worth an upstream issue once
root-caused.

**Resolved, same day**: `defer-launch-attach: t`'s stall turned out to point
at the actual mechanism, even though it wasn't the fix itself. Re-reading
dape.el's `initialized`-event handler alongside the `initialize`-response
handler suggested a specific hypothesis: lldb-dap likely only emits the
`initialized` event as a side effect of having already received `launch` --
not independently, the way the "textbook" DAP interpretation assumes. With
`defer-launch-attach: t`, dape withholds `launch` until after the
`initialized`-triggered chain completes, which never happens if lldb-dap is
gating `initialized` behind `launch` -- a genuine chicken-and-egg, matching
the observed stall exactly.

This reframes the problem: instead of trying to fix the *ordering* of
`launch` vs `setBreakpoints`, sidestep the race's timing sensitivity
entirely. lldb-dap's own documentation (`lldb.llvm.org/use/lldbdap.html`)
confirms `stopOnEntry` as a supported launch argument, and dape.el already
has precedent for passing it through for other adapters. Added
`:stopOnEntry t` to `lldb-dap`/`lldb-vscode` in `dape-config.el`, keeping
`defer-launch-attach` at its default (unset). With this, the process always
pauses at its very first instruction, regardless of breakpoints -- giving
the late-arriving `setBreakpoints` request as much time as it needs to
register before anything resumes. **Verified live, twice, in the user's
actual `run.sh` container**: launch stops at entry (`signal SIGSTOP`,
frame in `ld-linux-aarch64.so.1`), one `dape-continue` reaches the real
breakpoint correctly (`flight_test::main` / `src/main.rs:18` in the first
run, `:17` after a clean rebuild fixed a stale-binary line-number mismatch
in the second), with a full accurate backtrace both times.

**UX cost, worth knowing**: every `SPC d d` now stops once at the process
entry point before your own breakpoints are reachable -- `SPC d c` once to
get past it. Small price for breakpoints working at all.

**How the investigation actually ended**: while confirming this fix a
third time for certainty, `emacsclient` calls stopped responding entirely.
`ps aux` inside the container showed the main `emacs` process in state `R`
(actively running, not blocked) with 16+ minutes of accumulated CPU time --
genuinely spinning, not deadlocked on I/O -- alongside **five** separate
`lldb-dap`/`lldb-server` process pairs still alive from earlier test
launches that had never been cleanly disconnected, plausibly confusing
dape's connection-selection logic into a busy loop. Attempted recovery via
`kill -SIGINT` on PID 1 inside the container -- not realizing PID 1 *is*
Emacs itself here (this image's `CMD` is `["emacs"]` directly, no separate
init process) -- which terminated the entire container instead of just
interrupting the stuck operation. All unsaved session state (any breakpoints
not yet persisted, buffer state) was lost; the container needed a full
`./run.sh` restart. The fix itself was already safely written to
`dape-config.el` on disk before this happened, so no investigation work was
lost -- only the live session state.

**Lesson for next time**: never send signals to PID 1 inside a container
without first confirming what PID 1 actually is in that specific image --
`docker exec <container> cat /proc/1/comm` (or checking the Dockerfile's
`CMD`) is a cheap, mandatory check before any signal-based recovery attempt,
since PID 1 has no default signal handlers the way a normal process does
and many images (this one included) run the actual application directly as
PID 1 rather than under a supervisor.

**Update**: DECISIONLOG.md now has the full entry for the race condition +
`stopOnEntry` fix. The container was restarted via a fresh `./run.sh` and
the fix was re-verified end-to-end against that clean start (see this
file's own account above). Still not yet done: none of this has been
tested on x86_64 (aarch64-only so far, same caveat as the rest of this
debugging saga).

#### C/gdb debugging validated live — and a real, IDE-wide gap found along the way

Circled back to confirm the one thing the original C/CMake entry (and its
debugger follow-up) had explicitly flagged as unverified: an actual live
gdb debug session against the C flight-test project. Set a breakpoint,
launched via the real `SPC d d` -> dape -> gdb flow -- and the program ran
straight through, ignoring it, same outward symptom as the lldb-dap race
condition above.

**Not the same bug.** `objdump --dwarf=info` on the flight-test's compiled
binary came back completely empty -- zero DWARF debug info. Its
`CMakeLists.txt` sets no `CMAKE_BUILD_TYPE`, and CMake's default with
nothing specified passes neither `-g` nor `-O2` at all. gdb had nothing to
break on, correctly wired or not -- not a launch-ordering race, not a
container issue, just an ordinary unconfigured build.

**The bigger finding**: this project's own `+cmake/configure` binding
(`SPC m b c`, `cmake-keybindings.el`) ran the identical bare
`cmake -B build -S .` with no build-type flag -- meaning every C/C++
project debugged via this IDE's own recommended default workflow would
hit the same silent "breakpoints never work" wall, not just this one
fixture. Fixed by adding `-DCMAKE_BUILD_TYPE=Debug` to `+cmake/configure`
itself, so debug builds are the default rather than something a user has
to know to ask for.

**Verified live**: rebuilt the flight-test with the fixed configure
command, confirmed `.debug_info` now present, cleared stale breakpoints
left over from the same day's Rust testing (a mix of `.c` and `.rs`
breakpoints had accumulated in the same live session), set one fresh
breakpoint, launched -- correct stop at `main.c:6`, locals populated
(`unused 42`, `g` present). Applied to both trees.

#### Field notes from actually driving the C debugger, same session

Three smaller things surfaced while using the now-working debugger for
real, past the initial "does it stop at a breakpoint" check -- none of
them bugs in this project's own config, all worth having on record.

**`SPC d d` doesn't know which debugger a language "should" use.** In a
`c-mode` buffer, the prompt came back pre-filled with `lldb-dap`, not
`gdb` -- confirmed via `dape-history`, which held exactly `("lldb-dap")`
from the same day's earlier Rust testing. `dape--read-config` (read
directly from `dape.el`) prefers the most recent history entry that's
still valid for the *current* buffer's mode over any notion of "the
right debugger for this language" -- and since `lldb-dap`'s `modes` list
deliberately still includes `c-mode`/`c++-mode` (see the earlier
DECISIONLOG.md entries), a Rust-session choice is a legitimate, silently
pre-filled suggestion in a C buffer too. Not a bug -- both configs are
genuinely valid for C -- but a real trap for muscle memory: accepting the
prompt without reading it gets you the wrong debugger for what's actually
tested here. No code fix; just something worth knowing.

**Live variable editing works as expected.** Confirmed `dape-info-variable-edit`
(bound to `=` in the Scope buffer's own line-local keymap, not a global
`SPC d` binding) against a paused C session -- expanded a struct with `e`
(`dape-info-scope-toggle`), edited two of its fields by hand mid-pause,
continued execution, and the edited values were what the next function
call actually used. First real exercise of this feature in this project.

**Paused-program stdout can be invisible without being lost.** The
flight-test's `print_greeting` uses a bare `printf`, no `fflush`, no
`setvbuf` -- confirmed by reading `greet.c` directly. Standard C behavior:
stdout auto-switches from line-buffered to fully-buffered the moment it's
not attached to a real terminal, which a DAP-captured subprocess's output
always is. Stepping past the `printf` call didn't show anything in
`*dape-repl*` because the write was sitting in the C runtime's own
internal buffer, not because the debugger failed to capture it -- it
shows up on program exit, or on demand by sending `` call fflush(stdout)``
directly to the paused process via the REPL (per its own welcome message:
"input starting with a space is sent directly to the debugger"). Not a
bug anywhere in this stack; a general, easy-to-forget consequence of how
piped stdout behaves, worth remembering for any future language's own
debugger validation pass.

---

#### Go/dlv debugging validated live -- same class of root-detection bug as CMake's, one layer further down

Circled back to validate the one debugger integration from this whole
systems-ide effort that had never actually been driven end-to-end: Go's
`dlv` config, working since the original Go bring-up by every account in
this log, but never live-tested against a project nested inside a larger
git repo the way flight-tests/go/ is.

`SPC d d` against `flight-tests/go/flight-test.go` errored immediately:

```
Building .Build Error: go build -o /home/josiah/Development/personal/automation-engineering/docker-emacs/__debug_bin1939784951 -gcflags all=-N -l .
go: cannot find main module, but found .git/config in /home/josiah/Development/personal/automation-engineering/docker-emacs
	to create a module there, run:
	go mod init (exit status 1)
```

`go build` ran from the docker-emacs repo root, not from flight-tests/go/
where the actual `go.mod` lives. dape's built-in `dlv` config launches
delve with `:program "."`/`:cwd "."` -- both resolved by delve itself
relative to the *adapter process's own* working directory
(`command-cwd`, defaulting to `dape-command-cwd` -> `project-current`).
Traced live via `emacsclient -e`: `project-current` was returning the
docker-emacs repo root, not flight-tests/go/, even after confirming
`go.mod` sits right there and even after adding `"go.mod"` to
`project-vc-extra-root-markers` and clearing project.el's own root
cache by hand -- the marker made no difference at all. Root cause one
layer further down than expected: Doom prepends `project-projectile`
ahead of project.el's own VC backend in `project-find-functions`
(confirmed via `(default-value 'project-find-functions)` against the
live daemon), so it's Projectile's root-finding that actually wins, and
`projectile-project-root-files-bottom-up` -- the marker list that
correctly handles a project nested inside a bigger VCS tree -- has no
`go.mod` entry at all (nor `CMakeLists.txt`, for what it's worth; C/CMake
just never hit this because `+dape-cmake-program` already bypasses
`project-current` entirely for its own `:program` resolution).

Exact same class of bug as `+cmake--root`'s near-miss from the original
C/CMake bring-up -- project-root machinery assuming a VCS boundary is
the real project boundary -- just surfacing here because Go's dlv config
is the one debugger integration in this file that never got its own
`locate-dominating-file`-based bypass the way cargo and CMake did.

**Fix:** `dape-config.el` gains `+dape-go-root`, walking up for `go.mod`
directly (same shape as `+dape-cargo-program`/`+dape-cmake-program`),
and overrides the `dlv` config's `command-cwd` to use it instead of
dape's default `project-current`-based guess. No change to
`project-vc-extra-root-markers` or Projectile's own root-file lists --
narrower blast radius, and consistent with how the other two debuggers
already sidestep project-root detection rather than trying to fix it
globally.

**Verified live, twice** (once patching `dape-configs` ad hoc via
`emacsclient -e` to confirm the fix shape works at all, once more after
writing the real fix to `dape-config.el` and `load-file`ing it fresh into
the running daemon to confirm the actual on-disk file is what's tested,
not a hand-patched approximation of it): `SPC d d` now builds from
flight-tests/go/ correctly, breakpoint on `fmt.Println(message)` stops
there with `message "Hello"` populated in the Scope buffer. Only verified
on aarch64 so far; x86_64 mirrors the same fix but hasn't been
independently confirmed against its own rebuilt image.

**Not yet done:** this fix lives in the source tree only -- the running
container this was tested against had `dape-config.el` reloaded live via
`load-file` for verification, but its baked-in image still predates this
change. A rebuild is needed before `SPC d d` picks this up by default in
a fresh container.

---

#### Follow-up, same session: the Go fix wasn't the whole story -- gdb/lldb-dap/lldb-vscode had the identical bug

Right after the Go/dlv fix above landed, a second look at Rust's own
flight-test (previously confirmed working earlier this same session) now
failed too, complaining about being unable to find its `Cargo.toml` --
and C's gdb session, tested separately, showed the exact "No source file
named .../main.c ... Breakpoint 1 ... pending" symptom from way back at
the start of tonight's debugging (originally assumed, at the time, to be
purely the missing-debug-symbols bug -- it wasn't only that).

**Root cause, one layer deeper than the Go fix reached:** dape's
`dape--guess-root` -- called to bind `default-directory` *before*
`:program` gets evaluated for any config -- reads a config's own
`command-cwd` first, falling back to `dape-command-cwd` only if unset.
`gdb`/`lldb-dap`/`lldb-vscode`'s built-in configs all default `command-cwd`
to `dape-command-cwd` too, exactly like `dlv` did. Fixing only `dlv`'s
`command-cwd` left the other three routing through the same broken
`project-current` chain -- but where Go's `dlv` has no `:program`
resolver of its own and fails loudly ("cannot find main module"), gdb/
lldb-dap's `+dape-cargo-program`/`+dape-cmake-program` resolvers just
silently found no root either (their own internal
`locate-dominating-file` calls, poisoned by the same wrong
`default-directory`) and fell through to dape's literal `"a.out"`
default -- a much quieter failure that read, at first glance, like a
missing binary rather than a resolution bug.

**Fix:** `dape-config.el` gains `+dape-resolve-cwd` (tries `Cargo.toml`,
then `CMakeLists.txt`, same shape as `+dape-resolve-program`), applied as
`command-cwd` for `gdb`/`lldb-dap`/`lldb-vscode` alongside the existing
`:program` override. `+dape-go-root` stays as `dlv`'s own separate
`command-cwd`, since Go's marker file is different and it has no
`:program` resolver to share logic with.

**Verified live, all three languages, in the docker-emacs repo's own
nested flight-test copies** (not the `~/flight-tests/` image-baked
copies, which never hit this since they're not nested inside a larger
git tree):
- Go: `dlv` build succeeds from `flight-tests/go/`, breakpoint stops with
  `message` populated (already covered above).
- Rust: `lldb-dap` launches `flight-tests/rust/target/debug/flight-test`
  correctly, `:stopOnEntry` pause then `dape-continue` reaches
  `flight_test::main` / `src/main.rs:17` with `message`/`c` populated.
- C: `gdb` resolves `flight-tests/c/build/ctest` correctly, breakpoint on
  `print_greeting(&g);` stops with `unused 42`/`g` populated. (The
  "Breakpoint 1 ... pending" message still prints during the request
  race -- gdb warns and self-heals once the binary loads, same
  warn-and-proceed character as its ASLR/`personality()` behavior
  documented in DECISIONLOG.md -- but the breakpoint now resolves
  correctly instead of staying pending forever with no binary to attach
  to.) Confirmed independently by re-testing both gdb and lldb-dap
  against the C fixture after this fix.

Only verified on aarch64 so far; x86_64 mirrors the same fix but hasn't
been independently confirmed against its own rebuilt image. Same
not-yet-rebuilt caveat as the entry above -- this was verified via
`load-file` into the running daemon, not a fresh container boot.

---

#### Python gets a real debugger

`python3-debugpy` added via apt (not pip -- keeps this tier's "no pip/
poetry/conda" rule intact; it's an `Architecture: all` package in
Ubuntu's universe repo, no per-arch build needed). dape already has a
built-in `debugpy`/`debugpy-module` config, so no new dape-config.el
entry was needed the way Lua required one. One real gap found and fixed:
this image ships only a versioned `python3`, no bare `python`, and
dape's built-in config hardcodes `command "python"` -- same shape of gap
`lua5.4`/`lua` needed fixing for Lua, fixed the same way (a symlink under
`~/.local/bin`).

Ruby deliberately does not get an equivalent -- see DECISIONLOG.md for
the full reasoning (pry through the existing `inf-ruby` REPL integration
already covers that need there, and Python's glue scripts have shown
more real debugging need in practice than Ruby's have).

Verified live: breakpoint inside `main()` in `flight-tests/python/
deploy.py`, correct stop, clean continue through `import tasks` to exit.
`debugpy` itself couldn't be installed via apt in the already-running
container (no network access at runtime, by design -- confirmed the hard
way when a live `apt-get update` attempt hung on DNS resolution, same
failure mode as the earlier lldb-dap DEBUGINFOD_URLS hang). Verified
instead by vendoring the actual `.deb`'s Python package files in from a
disposable `docker run ubuntu:26.04` container (which does have build-
time network access) directly into the running container's
`dist-packages`, purely for this test -- the real install path (baked in
at image build time, via apt) is untouched and unaffected by this.

Only verified on aarch64 so far; x86_64 mirrors the same fix but hasn't
been independently confirmed against its own rebuilt image.

---

#### The Cargo.toml-not-found bug reappears at the LSP layer

Reported live: opening `flight-tests/rust/src/main.rs` in this repo's own
nested copy, rust-analyzer failed to find `Cargo.toml` -- despite the
dape/debugger side of this exact symptom already being fixed twice
tonight (`+dape-resolve-cwd`/`+dape-go-root` in `dape-config.el`, and the
broader command-cwd generalization). Confirmed live: `lsp-workspaces`
showed `rust-analyzer` connected, but `lsp--workspace-root` reported the
outer `docker-emacs` repo root, not `flight-tests/rust/` --
`rust-analyzer`'s own stderr log showed repeated `failed to find any
projects in [.../docker-emacs]` / `FetchWorkspaceError`. Checked Go
(`gopls`) and C (`clangd`) the same way -- both showed the identical
wrong-root symptom against their own nested flight-test copies.

**Root cause, one layer above the debugger-side fixes:** `lsp-mode`'s own
workspace-root detection (`lsp-auto-guess-root`, already `t` in this
project) ultimately calls `lsp--suggest-project-root`, which calls
`projectile-project-root` first -- not `project-current` directly, and
entirely independent of `dape`'s own resolution machinery, which is why
fixing the debugger side earlier tonight never touched this. Doom
prepends `project-projectile` ahead of `project.el`'s own VC backend in
`project-find-functions` (already known, from the Go/dlv investigation
earlier), and `projectile-project-root-files-bottom-up` -- the marker
list that correctly returns the *closest* match for a project nested
inside a bigger VCS tree -- ships with only version-control markers by
default, missing `Cargo.toml`/`go.mod`/`CMakeLists.txt` entirely. Every
"full support" tier flight-test fixture in this repo hit this the same
way: LSP initialized against the wrong (outer) workspace root, silently
unable to find any project file.

**Confusion along the way, worth recording honestly:** live-patched the
fix directly into the running daemon (`add-to-list
'projectile-project-root-files-bottom-up ...`) mid-investigation, then
appeared to still intermittently fail on repeated checks -- both
`project.el`'s own per-directory root cache and Projectile's own
`projectile-project-root-cache` cache lookups, and several concurrent
`rust-analyzer` processes left over from repeated test invocations in
quick succession (confirmed via `pgrep` and a "duplicate
DidOpenTextDocument" error in `*rust-analyzer::stderr*`), made it look
flakier than the underlying fix actually was. Once caches cleared and a
single clean connection was re-established, Rust/Go/C all resolved
correctly and stayed that way.

**Fix:** `config.el` gains a new `(after! projectile ...)` block (grouped
under a new "LSP adjustments" section header alongside the pre-existing
`(after! lsp-mode ...)` block), adding `Cargo.toml`/`go.mod`/
`CMakeLists.txt` to `projectile-project-root-files-bottom-up`.

**A real tradeoff considered, not just assumed away:** bottom-up search
returns the *closest* marker match -- a genuine multi-module CMake
project (umbrella `CMakeLists.txt` with `add_subdirectory()`
subprojects, each having their own nested `CMakeLists.txt`) would resolve
to the innermost subdirectory, not the umbrella root. Accepted as a known
limitation rather than switching to `projectile-project-root-files-top-
down-recurring` (which returns the *outermost* match instead, built for
exactly this shape, but with the opposite failure mode: it would
incorrectly swallow a genuinely separate, accidentally-nested unrelated
project). Rust/Go are much less exposed to this in practice than C/CMake
-- rust-analyzer and gopls both self-discover their true workspace root
from workspace-aware manifests (`Cargo.toml`'s `[workspace]`, `go.work`)
once pointed at any member, independent of what directory `lsp-mode`
initially guessed. clangd is less certain (its own `compile_commands.json`
discovery walks up from the source file independently of the LSP-
reported root, which may make it more tolerant of this than expected, but
wasn't verified against a real multi-module CMake project tonight).
Likelihood assessed as low for this project specifically -- none of the
current flight-test fixtures have this shape -- revisit if a real
multi-module project is ever opened in one of these containers.

**Cross-util jump-to-def, a related but separate question:** for a
future repo with several small language-specific utils that call into
or link against each other, this fix (and `lsp-auto-guess-root` in
general) only governs the *automatic*, zero-effort root guess -- it
doesn't preclude telling lsp-mode about a broader scope on purpose.
Rust/Go both have native mechanisms for exactly this (Cargo workspace
members, `go.work`), independent of the bottom-up heuristic entirely.
C/CMake has no equivalent workspace manifest; the answer there is either
one umbrella `CMakeLists.txt` with `add_subdirectory()` (one build, one
`compile_commands.json`, one clangd session automatically), or manually
calling `lsp-workspace-folders-add` to add a second directory into the
same clangd session -- a normal, supported multi-root workflow, not a
workaround.

**How to manually override the guessed root, when needed:** `lsp-auto-
guess-root` being globally `t` (needed for the daemon/smoketest flow)
short-circuits `lsp-mode`'s own interactive root picker
(`lsp--find-root-interactively`) entirely -- confirmed by reading
`lsp--calculate-root`'s actual `or` chain, which tries
`lsp--suggest-project-root` first and only reaches the interactive
prompt when auto-guess is off. `SPC c l w s` alone, with auto-guess still
on, just re-runs the same (possibly wrong) guess. The actual override:
`M-: (setq-local lsp-auto-guess-root nil)` in the buffer in question,
then `M-x lsp` -- this reaches the real prompt (import suggested root /
select root directory interactively / import at current directory /
blocklist), buffer-locally, without touching the global setting the
smoketest flow depends on.

**Turned into real commands, same session:** the manual recipe above
got wrapped into `polyglot-keybindings.el` (new file -- cross-cutting
dev-tooling keybindings that aren't specific to any one language's own
file, and aren't purely editor-level either): `lsp-pick-root` (bound to
`SPC c l w S`) does the `setq-local`-then-`lsp` dance directly, and
`lsp-restore-auto-guess-root` undoes the buffer-local override via
`kill-local-variable` (there's no other built-in way to un-set it for a
single buffer once `lsp-pick-root` has run). Also explored and rejected,
worth recording: `.dir-locals.el` setting `lsp-auto-guess-root` to `nil`
per-project (verified live -- it does correctly make every subsequent
file in the project resolve to the already-picked root automatically,
no repeated prompting) in favor of a still-open question about whether
`lsp-pick-root` should write that file itself; not built yet.

**A real elisp-formatting bug found while writing that file:** Doom's
`map!` has no `(declare (indent N))` of its own, and `:prefix` (its
nested-prefix DSL keyword) isn't a real special form either, so nested
`(:prefix "x" (:prefix "y" ...))` forms indent with cascading, ever-
increasing offsets by default -- confirmed live, and fixed with
`(put ':prefix 'lisp-indent-function 1)` in a new `all-lisps-config.el`
(numeric `1`, not `'defun` -- tested both live; `'defun` gives the same
clean per-level nesting step but leaves a form's own body one column off
from its positional argument, while `1` aligns them exactly). Confirmed
this is process-wide, not scoped to emacs-lisp-mode -- affects `lisp-mode`
and `scheme-mode` too, relevant given Guile/SBCL/Racket support being
considered for this project. A genuine per-project override remains
possible without touching this global property: `calculate-lisp-indent`
reads it through an ordinary, buffer-local-able `defcustom` also named
`lisp-indent-function` (confusingly, the same name as the property) --
a project's own `.dir-locals.el` can rebind that variable instead,
cleanly, the same way `lsp-auto-guess-root` already does.

Verified live against Rust, Go, and C's nested flight-test copies after
the fix: workspace root correctly resolves to each project's own
directory, not the repo root. Only verified on aarch64 so far.

### 2026-07-21 — Guile added as a ninth full-support language, plus a standalone Guix image and in-container package manager

Guile earns full support specifically because it's the implementation
language of GNU Guix (the Nix-equivalent in the Scheme world), not just
general GNU-ecosystem affinity — the user wanted Guix package-manager
support wired in alongside it, not deferred. See DECISIONLOG.md for the
apt-vs-Guix-sourced Guile reasoning and the Docker/Podman-vs-in-container
daemon architecture reversal.

**New standalone `guix-source` image** (`30.2/ubuntu/*/guix/`, both
trees, modeled on `nix/Dockerfile`): downloads the official Guix binary
tarball (`guix-binary-1.5.0.<arch>-linux.tar.xz`, checksum-pinned) and
extracts it — no `guix-daemon` involved at all for this. Guix is itself
implemented in Guile, so a full Guile closure (confirmed: `guile-3.0.9`
at this Guix version) is already a transitive dependency of the `guix`
package sitting in the store right after extraction; it's just not
symlinked into `guix`'s own profile `bin/` by default. Discovering the
store path at build time (rather than hardcoding the content-addressed
hash, which is tied to this exact Guix release) and symlinking
`guix`/`guix-daemon`/`guile`/`guild`/`guile-config` into `~/.local/bin`
was all that was needed. Verified live: `guix --version` (1.5.0),
`guile --version` (3.0.9), a real Guile eval, full 5/5 smoketest.

**`systems-ide` wiring:** `COPY --from=guix-source /gnu /gnu` +
`/var/guix /var/guix` (mirroring the existing Nix COPY pattern exactly),
`(scheme +guile)` in `init.el`, `(load! "guile-keybindings")` in
`config.el`. No `guile-config.el`, no `packages.el` entry — Doom's own
`lang/scheme/config.el` already wires `set-lookup-handlers!`,
`flycheck-guile`, and an extensive localleader map with zero extra
config, confirmed via direct source read before writing anything.
`flight-tests/guile/{utils.scm,main.scm}` mirrors Lua's `init.lua`+
`utils.lua` split. New smoketest cases: guile version, `.scm` activates
`scheme-mode`, `flycheck-guile` connects, localleader format-buffer
resolves.

#### A latent bug in `polyglot-keybindings.el` broke every language's localleader bindings, found while verifying Guile's

First full smoketest run after wiring Guile showed 13+ *unrelated*
localleader keybinding tests failing simultaneously (rust, go, nix, sh,
bats, nu, c, lua, python, ruby, javascript, cmake, typescript, guile) —
too broad to be a Guile-specific bug. `--debug-init` plus a `featurep`
check on every `load!`-ed file in `config.el` gave precise ground truth:
every file from `polyglot-keybindings.el` onward never loaded, because
that file's own `map!` call errored synchronously at Doom-config load
time (`Key sequence c l w S starts with non-prefix key c l`), and that
error propagates all the way up through `doom-load`'s re-signaling
chain to the single outer `condition-case` around the entire
`doom-startup` sequence — aborting every subsequent `load!` call project-
wide, not just this file's own content.

Root cause: `SPC c l` (where `lsp-pick-root`, added earlier this
project's history, was nested as `SPC c l w S`) is bound directly to
`+default/lsp-command-map`, a plain interactive command (Doom's own
flat LSP action palette, confirmed via `(keymapp (symbol-function
'+default/lsp-command-map))` → `nil`) — not a real nestable keymap the
way the original design assumed. `map!`'s `:prefix` nesting can only
extend genuine keymaps, so trying to nest further under it fails
immediately, every time, regardless of load order or `after!` wrapping
(confirmed: wrapping in `after! lsp-mode` doesn't help, since the
binding still isn't a keymap once lsp-mode loads either). Fixed by
moving `lsp-pick-root` to a fresh top-level `SPC l w S` prefix instead
of trying to nest under Doom's own `SPC c l`. Verified via `(lookup-key
doom-leader-map (kbd "l w S"))` directly (bypasses buffer/evil-state
ambiguity that a plain `key-binding` check is sensitive to) before and
after rebuilding the real image; full smoketest re-run confirmed every
previously-failing localleader test now passes.

Separately found, not fixed (unrelated, deferred, non-blocking):
`bats-config.el` throws "Unknown type lsp--client" from a `cl-typep`
inliner failure inside its own deferred `eval-after-load 'lsp-mode`
callback — doesn't cascade like the above (the error fires later, after
`bats-config.el`'s own `(provide ...)` already ran), so it didn't block
anything, but is a real latent bug in that file's bash-ls/bats-mode
association worth a look later.

#### Guix daemon runtime support (Phase 3): making `guix install` work self-contained, not bridged to a host daemon

Originally planned as a Docker/Podman-style client-bridge (`guix`
client in the container, `guix-daemon` running on the host or a
sidecar) — reversed during planning once it was pointed out this makes
Guix support fully dependent on an external daemon staying reachable,
with zero in-container fallback, unlike every other package manager
this project supports. Revised to run `guix-daemon` *inside*
`systems-ide` itself, started at container *runtime* (not build time) —
sidesteps the daemon-during-a-`RUN`-layer restriction entirely, since
that restriction is specific to `docker build`, not a running
container.

New `entrypoint.sh`: starts `guix-daemon --build-users-group=guixbuild`
in the background via passwordless `sudo` (added for `${USERNAME}`,
matching `nix-source`/`guix-source`'s own convention), waits for the
daemon socket, then `exec`s `"$@"` (`emacs`). `systems-ide` previously
had no entrypoint at all (`CMD ["emacs"]` launched Emacs straight as
PID1) — now `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]` +
`CMD ["emacs"]`. The `guixbuild` group and its 10 `guixbuilder`
unprivileged build users are created at build time (ordinary
`useradd`/`groupadd`, no daemon involved, folded into the existing
user-creation layer).

Four requirements found only by testing live, beyond the daemon
itself — each fix uncovering the next blocker further into an actual
build, not found all at once:
- **`netbase`** — a minimal Ubuntu image has no `/etc/services` at all
  (confirmed directly), so `guix-daemon`'s build sandbox fails every
  network fetch, including fixed-output derivations, with `getaddrinfo:
  Servname not supported for ai_socktype`. One apt package fixes it.
- **`--security-opt seccomp=unconfined`** — the sandbox calls
  `personality()` (disables ASLR for reproducible builds), blocked by
  Docker's default seccomp profile.
- **`--cap-add SYS_ADMIN`** — the sandbox also calls `clone()` to
  create its own nested namespaces per build, blocked independently of
  seccomp by Docker's default capability set (`clone: Operation not
  permitted`) — only surfaced after fixing the two above.
- **`--cap-add NET_ADMIN`** — the sandbox also brings up a loopback
  interface inside its own new network namespace, needing this
  capability separately from `SYS_ADMIN` (`cannot set loopback
  interface flags: Operation not permitted`) — only surfaced after
  fixing all three above, i.e. after getting substantially further
  into a real build (past dozens of fixed-output derivation fetches).

None of the three flags are a new category of risk here: `systems-ide`
already bridges `docker.sock`, which alone is already host-root-
equivalent trust (see DECISIONLOG.md), and the realistic alternative to
containerizing this at all is running the same tooling directly on the
host with the same `docker`-group privileges anyway.

**A fifth bug, found only once testing against the real `systems-ide`
image rather than the isolated `guix-source` test:** `entrypoint.sh`'s
`sudo guix-daemon ...` failed with `guix-daemon: command not found` —
`sudo` resets `PATH` to its own `secure_path` by default (confirmed
live: `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:
/snap/bin`), which doesn't include `~/.local/bin`, where `guix-daemon`
is symlinked. Fixed by invoking `sudo "$HOME/.local/bin/guix-daemon"`
directly rather than relying on PATH lookup through `sudo`.

**Verified, precisely, what "verified" means here:** the isolated
`guix-source` test (a throwaway container, same discipline as that
image's own build-time verification) confirmed the build-sandbox
mechanism itself works — `guix install hello` progressed correctly
through privilege-dropping (build processes run as the unprivileged
`guixbuilder*` users, confirmed via direct process inspection) and
dozens of real fixed-output derivation downloads, well past all four
blockers above, before being left running in the background rather
than waited out to completion (substitutes didn't match this exact
channel revision, so `hello` needed a full from-source bootstrap —
gcc, glibc, and eventually the Linux kernel source itself — genuinely
long-running, and orthogonal to whether the sandbox is configured
correctly). Separately, and more directly relevant: rebuilding the real
`systems-ide` image with the `entrypoint.sh` fix and running it with
`--security-opt seccomp=unconfined --cap-add SYS_ADMIN --cap-add
NET_ADMIN` confirmed `guix-daemon` starts correctly (socket present,
process running as expected) with no reliance on the isolated test's
outcome. Full smoketest re-run after this fix: still 76/78 (the two
pre-existing, unrelated failures — `vcpkg` version, `.h` file mode —
unchanged, no regressions introduced).

A real, external Codeberg outage (HTTP 503, confirmed via `curl` across
multiple retries a minute apart) blocked `geiser`'s clone (its MELPA
recipe points exclusively at `codeberg.org/geiser/geiser`) for part of
this session — resolved on its own; not a project issue. Second
Codeberg-hosted-project outage this week during late US evening hours,
both resolved by morning.

#### Follow-up, same day: two more real bugs found by actually driving the running container end to end

Everything above was verified via `smoketest.bats` plus one-off
`emacsclient --eval` checks against a running daemon. Actually launching
`systems-ide` via its real `run.sh` and working through the Guile flight
test the way a real session would (open file, open REPL, evaluate)
surfaced two more real, previously-invisible bugs.

**Bug 1 — Doom's own Guix load-path integration errored on every REPL
connect.** Doom's `:lang scheme +guile` module conditionally runs
`(add-to-list 'geiser-guile-load-path
"~/.config/guix/current/share/guile/site/3.0")` whenever `guix` is on
PATH. `~/.config/guix/current` is Guix's own standard per-user profile
symlink (created by the official `guix-install.sh`), which this
project's simplified tarball-extraction `guix-source` approach never
created — only individual binaries got symlinked into `~/.local/bin`.
Every Guile REPL connect logged `In procedure stat: No such file or
directory` for that path. Fixed: `systems-ide`'s Dockerfile now also
symlinks `~/.config/guix/current` to the extracted profile, matching
Guix's own convention. Confirmed live, both before (error) and after
(clean `ge:add-to-load-path` success) the fix.

**Bug 2 — the flight-test fixture's own module-loading idiom doesn't
survive Geiser's per-form evaluation.** `main.scm` opens with
`(add-to-load-path (dirname (current-filename)))`, which works fine for
a plain `guile main.scm` run (confirmed earlier this session) but
silently fails to find `utils.scm` when a real user evaluates the
buffer through Doom/Geiser (`SPC m e e`/`e b`) — confirmed directly:
`(defined? 'greet)` came back false after evaluating every form in the
file that way. Root cause: Geiser doesn't tell Guile to *load* the
file when you eval a form or a buffer — it sends the form's *text*
straight to the REPL, the same as if you'd typed it. Guile is never
actually reading through `main.scm`, so `(current-filename)` (which
only means something while a file is genuinely being read top to
bottom) has nothing to point to. `(getcwd)` doesn't help either --
confirmed live it resolves to the outer repo root inside this REPL, the
same `doom-project-root`/Projectile chain already documented above, not
the fixture's own directory.

Fixed with `flight-tests/guile/.dir-locals.el`:
```elisp
((scheme-mode . ((eval . (add-to-list 'geiser-guile-load-path default-directory)))))
```
`default-directory` doesn't have the `current-filename` problem —
Emacs always knows a buffer's own directory unambiguously, regardless
of how its contents get evaluated afterward. This moves the "where am I"
question from Guile's side (broken under Geiser) to Emacs's side
(always correct).

**A real security consideration, not glossed over:** `eval` in
`.dir-locals.el` is untrusted by default — Emacs prompts before running
it, which would hang a headless smoketest run (and did, twice, during
this investigation, alongside an unrelated `kill-buffer`-on-a-live-
process prompt hit while debugging the *original* bug — both self-
inflicted testing artifacts, not integration bugs, but worth remembering
that any confirmation prompt hangs a scripted `emacsclient` session).
Rejected `enable-local-eval` (would trust eval forms in *every* project
this Emacs ever opens) in favor of whitelisting this one exact form via
`safe-local-eval-forms` in `config.el` — same reasoning already applied
to `seccomp`/`SYS_ADMIN`/`NET_ADMIN` elsewhere this session (match the
scope of trust to what's actually needed), but this time the user
caught it directly rather than it being proposed proactively.

Verified live, end to end, after both fixes: opening `main.scm`,
connecting the REPL, and evaluating `(begin (use-modules (utils))
(greet "systems-ide"))` returns the correct
`"Hello from Guile, systems-ide!"`. Full smoketest re-run: still 76/78,
no regressions.

#### Closing the loop: a real `guix install` completing inside `systems-ide` itself, not just the isolated test

Everything above about Phase 3 (`guix-daemon` starting correctly) was
verified either in the isolated `guix-source` test container or by
checking the daemon starts inside the real image -- never an actual
`guix install` run to completion *inside `systems-ide`*. Doing that
found one more real gap: `/etc/guix/acl` had zero authorized substitute-
server keys inside the container (confirmed directly), so every install
fell back to building entirely from source -- the same slow path that,
in the earlier isolated test, got deep into bootstrapping a full
toolchain (gcc, glibc, kernel headers) before hitting a genuine
`automake-1.17` build failure. The real Asahi host doesn't have this
problem because `guix-install.sh`'s own interactive flow authorizes
`ci.guix.gnu.org`/`bordeaux.guix.gnu.org` automatically when you answer
yes to its "permit downloading pre-built binaries" prompt -- `entrypoint.sh`
had no equivalent step.

Fixed by adding the same two `guix archive --authorize` calls
`entrypoint.sh` already does implicitly need, using the `.pub` key
files Guix ships in its own profile (`share/guix/*.pub` -- no need to
fetch or author anything). Runs on every container launch, same
reasoning as the build-users-group setup: the container is `--rm`, so
`/etc/guix/acl` starts empty every time. Verified live, twice, with two
different packages (`hello`, `tree`) in the real rebuilt image: both
install in seconds via substitutes and the resulting binaries run
correctly -- no from-source bootstrap needed at all anymore.

This also settled a real question worth recording plainly, at the time:
`run.sh` had no `/gnu`/`/var/guix` bind mounts from the host at all
(confirmed directly, unlike Nix's own host-store bind mounts) --
`systems-ide`'s Guix was *completely* self-contained, with zero
dependency on the host having Guix installed, working, or even
present. **Superseded by the very next section below** -- this framed
self-contained-vs-host-bridged as a permanent architectural choice,
when in fact `MOUNT_HOST_NIX` already proved (for Nix, in this same
file) that both properties can coexist behind one runtime toggle. The
self-contained behavior described above is now the `MOUNT_HOST_GUIX=0`
fallback path, not the only path.

#### `MOUNT_HOST_GUIX`: mirroring `MOUNT_HOST_NIX`'s host-bridge toggle for Guix

Prompted by a direct question: if Nix's `run.sh` bridge already proves
a container can share the host's real store *and* fall back to a
self-contained one when the host's install is missing or broken, why
was Guix framed as an either/or a section above? It wasn't -- that was
a framing mistake, corrected directly. The fix: give Guix the same
runtime toggle Nix already has, not a second permanent architecture.

Feasibility confirmed first with a standalone test against the host's
real daemon, before touching any code:

```
docker run --rm -v /gnu:/gnu:ro -v /var/guix:/var/guix \
  josiah14/guix:1.5.0-ubuntu-26.04 bash -c '
    guix package -I
    guix install --no-grafts which
'
```

This worked immediately, with no `GUIX_DAEMON_SOCKET` override --
`guix` looks for the daemon socket at its own default path
(`/var/guix/daemon-socket/socket`), and bind-mounting `/var/guix` at
that identical path is all it takes. `guix package -I` showed `guile`
already present, reading the *host's* real per-user profile directly.

Unlike Nix's bridge, no `ldd`-based host-binary-bridging wrapper
(`.host-nix-bridge`) is needed. Nix's wrapper exists because this
host's Nix binary lives outside `/nix` entirely (Fedora's nix-core
RPM); Guix's own binary lives inside `/gnu/store` itself, and because
the store is content-addressed, the container's own build-time-baked
`guix`/`guile` symlinks (pointing at specific store-hash paths) keep
resolving correctly transparently, even after the host's `/gnu`
replaces the container's local one -- confirmed live during this same
test.

`run.sh` (both aarch64 and x86_64 trees) gained a `guix_mounts` array
mirroring `nix_mounts`'s gating exactly:

```sh
guix_mounts=()
if [[ -d /gnu ]] && [[ "${MOUNT_HOST_GUIX:-1}" == "1" ]]; then
  guix_mounts+=(
    -v /gnu:/gnu:ro
    -v /var/guix:/var/guix
  )
fi
```

`/var/guix` is read-write (not `:ro` like Nix's `/nix` split) since it
holds the daemon's socket directory and per-user profile symlinks that
get rewritten on every `guix install`/`upgrade`.

`entrypoint.sh` needed a matching change: when the host bridge is
active, the host's own `guix-daemon` is already running and its socket
is already sitting at the bind-mounted path the moment the container
starts -- starting a second daemon here would just race the host
daemon for the same socket. Detected by the socket's own presence
(`[ -S /var/guix/daemon-socket/socket ]`) rather than reading
`MOUNT_HOST_GUIX` directly, since `entrypoint.sh` never receives
`run.sh`'s environment, only the mounts it set up. When bridged, both
the daemon-start and the substitute-key-authorization step from the
section above are skipped entirely -- the host's own `/etc/guix/acl`
already has those keys, from the original `guix-install.sh` run.

Verified live, both modes, against the real rebuilt image:

- **Bridged** (`-v /gnu:/gnu:ro -v /var/guix:/var/guix`, no extra
  flags): `entrypoint.sh` printed "bridged host daemon detected...
  skipping in-container daemon + key authorization"; `guix install
  tree` completed via the host daemon; confirmed the install actually
  landed on the *host's real profile* by running `guix package -I` on
  the host directly afterward -- `tree` was there.
- **Self-contained** (no host mounts, same `--security-opt
  seccomp=unconfined --cap-add SYS_ADMIN --cap-add NET_ADMIN` flags
  `run.sh` already sets): `entrypoint.sh` started its own daemon,
  authorized both substitute-server keys, `guix install hello`
  completed via substitutes, and the resulting binary ran and printed
  `Hello, world!`.

Full smoketest re-run after rebuilding with the new `entrypoint.sh`:
78/78, no regressions.

Net effect: `systems-ide`'s Guix now matches Nix's exact resilience
model -- host-bridged by default (shared store, persistent installs,
survives container restarts) with a same-session fallback to fully
self-contained if the host's Guix is ever missing, corrupt, or
mid-upgrade, via one env var (`MOUNT_HOST_GUIX=0`).

#### Fish, Assembly, and Perl -- the "syntax-only batch" upgraded to full LSP (mostly)

Two of the three ended up with real language servers rather than the
plain syntax-highlighting ROADMAP originally scoped, once research
turned up genuine, actively-maintained LSP options for both. Perl
stayed deliberately syntax-only by explicit request ("I hate Perl, code
in it is usually a mess, I want to discourage Perl use").

**Fish**: `fish-mode` (wwwjfy/emacs-fish, `packages.el`) self-registers
`.fish`/the `fish` interpreter shebang via its own `;;;###autoload`
cookies -- no manual `auto-mode-alist` wiring needed. `fish-lsp`
(ndonfris/fish-lsp, npm) has no built-in `lsp-mode` client, so
`fish-config.el` registers it by hand (`lsp-register-client` +
`lsp-stdio-connection '("fish-lsp" "start")`). Formatting needed no
override: apheleia already defaults `fish-mode` to its own
`fish-indent` formatter (`fish_indent`), confirmed directly from
`apheleia-formatters.el`'s source.

**Assembly**: `asm-lsp` (bergercookie/asm-lsp) turned out to have a
built-in `lsp-mode` client already (`clients/lsp-asm.el`, activates for
stock `asm-mode` out of the box) -- `asm-config.el` just forces its
lazy `(require 'lsp-asm)` inside `(after! lsp-mode ...)`, the same
shape `nu-config.el` already established for `lsp-nushell`. No Doom
`:lang asm` module exists (confirmed against the pinned commit's
`modules/lang/` tree), and none was needed: `asm-mode` ships built into
Emacs core with `.s`/`.S`/`.asm` already in the default
`auto-mode-alist`.

**Per-tree Dockerfile divergence, not a copy-paste**: asm-lsp has no
Linux/aarch64 prebuilt release (confirmed against the actual GitHub
release assets -- only `aarch64-apple-darwin`, `x86_64-apple-darwin`,
`x86_64-unknown-linux-gnu`), so the aarch64 tree installs it via
`cargo install asm-lsp --locked --version 0.10.1` after the Rust step.
First attempt failed outright: `openssl-sys` (a transitive dependency)
needs `pkg-config` to even locate `libssl-dev`, neither of which were
in the apt list -- added both, confirmed the rebuild then succeeds.
x86_64 *does* have a published Linux binary, so that tree uses the
prebuilt-tarball pattern instead (matching ruff/stylua), with zero
Rust-toolchain coupling and zero extra apt packages.

**A CLI-shape gotcha, caught by a version-check test that failed for
the right reason**: `asm-lsp --version` errors ("unexpected argument")
-- it's a clap subcommand CLI (`gen-config`/`info`/`version`/`help`),
not a flat `--version` flag. `asm-lsp version` is the actual
subcommand. Confirmed directly rather than guessed before fixing the
smoketest assertion.

**A real, deterministic bug found by the smoketest itself, not a
flake**: `asm-lsp connects for asm-mode buffers` failed consistently,
twice, in the full suite, despite the exact same assertion passing in
3 seconds against an isolated container with nothing else running.
Root-caused live by keeping a daemon alive past test failure (a
temporary `teardown_file` override) and inspecting it directly:
the buffer's *actual* major-mode was `go-asm-mode`, not `asm-mode`.
`go-mode.el` registers a `magic-mode-alist` predicate
(`go--is-go-asm`) that activates `go-asm-mode` instead of plain
`asm-mode` whenever a `.s` file's own directory contains any `.go`
file -- it's trying to detect Go's own runtime-assembly convention,
where `.s` files sit alongside `.go` sources in the same package
directory. `magic-mode-alist` is checked *before* `auto-mode-alist` in
Emacs's mode-selection order, so the extension mapping (which still
correctly says `.s` -> `asm-mode`, confirmed directly) never even gets
reached. `/tmp/smoketest/test.go` (this same fixture directory, added
for the Go language tests) was silently hijacking every `.s` file
opened anywhere else in that directory. Fixed by moving the assembly
fixture into its own `/tmp/smoketest/asm/` subdirectory -- `go--is-go-
asm` only inspects the file's *immediate* directory, so isolating it
sidesteps the collision entirely. Also tightened the mode-activation
test's regex to the literal quoted string (`\"asm-mode\"`) rather than
a bare substring match: `"go-asm-mode"` contains `"asm-mode"` as a
substring, meaning that test had been silently false-passing the whole
time this bug was live, only exposed once the LSP-connection test
(which checks the *server-id*, not the mode string) failed for real.

**Same class of bug, smaller blast radius, found by an explicit ask to
stop tolerating cosmetic test failures**: two long-pre-existing smoketest
failures (`vcpkg` version, `.h` file mode) turned out to be genuine,
fixable test bugs rather than real product gaps:
- `vcpkg version` self-reports vcpkg-tool's own build date (e.g.
  `2026-05-27-<sha>`), not the `VCPKG_VERSION` ports-registry tag this
  project actually pins (`2026.06.24`) -- two independent versioning
  schemes that happen to look similar. `bootstrap-vcpkg.sh` always
  fetches whatever vcpkg-tool release is current, which this Dockerfile
  never pins at all, so asserting a specific tool-binary version was
  never actually testing something this project controls. Rewritten to
  check it runs and self-identifies, not a hardcoded version.
- Opening `test.h` reliably activated `c++-mode`, not `c-mode`, once
  a same-basename `test.cpp` sibling existed in the same directory
  (confirmed live, isolated: with no `test.cpp` sibling, a fresh `.h`
  file reliably gets `c-mode`) -- Emacs's own `c-or-c++-mode` ambiguous-
  header heuristic disambiguates via a same-basename source-file
  sibling when one exists, the same *kind* of directory/sibling-content
  sniffing as `go--is-go-asm` above, different trigger (basename match
  vs. any `.go` file present). Fixed by renaming the fixture to
  `header-only.h`, a basename with no `.c`/`.cpp` sibling anywhere in
  the directory.

Both were genuinely order/fixture-sensitive, not flaky in the random
sense -- same inputs, same deterministic wrong answer, every time.
Neither was a bug in the actual IDE config; both were smoketest
fixtures unintentionally interfering with each other by sharing one
flat `/tmp/smoketest/` directory across every language's test files.

Full smoketest, all fixes applied: 86/86, zero pre-existing failures
remaining.

#### Fish and Assembly: don't assume LSP/debugger work, verify live -- one real bug found in each

Prompted directly: "fully test the Fish and Asm integrations, don't
assume they're working. Make sure LSP and the debugger work." Driven
entirely via `emacs --daemon` + `emacsclient --eval` (headless, no
display attached) rather than bats, since verifying real completion
lists/register state needs more than pass/fail assertions.

**Fish LSP, fully verified**: `textDocument/completion` on a real
buffer returned `("grep" "greet")` for the prefix `gre` -- `greet` is a
function *defined earlier in the same buffer*, proving semantic
analysis, not a static keyword list. Hover on `echo` returned real
content (command name + doc link), though the detailed man-page body
is degraded to Ubuntu's "minimized system" placeholder -- this image
has no `man-db` installed, a real but minor gap, left as-is rather than
adding a package just for fuller hover text. Diagnostics correctly
caught both a real syntax error ("missing closing token," an unclosed
`if`) and a semantic warning ("Unused local function 'greet'").

**Fish debugging**: no dape/DAP adapter exists for fish scripts
(confirmed: no `clients/lsp-fish`-equivalent in dape, and `fish-mode.el`
has zero REPL/inferior-process integration). Fish's own `breakpoint`
builtin is the real mechanism here (same shape as Ruby's `pry`) --
verified live via a `pty.fork()`-driven interactive fish session that
it genuinely works: `BP <function>:<line> >` is a real halting prompt,
variables are inspectable at it (`echo $x` -> `10`), and `exit` (not
`continue` -- that's fish's *loop* keyword, confirmed live it errors
"while not inside of loop") correctly resumes execution with the rest
of the function completing normally. One real, upstream limitation
found and confirmed against a matching open GitHub issue
(fish-shell/fish-shell#4823, open since the 2.7.1 era, "fish-future"
milestone, unfixed): `breakpoint` only works when the containing
function is *called as an interactive command at the prompt* -- it
does **not** pause when running a script file directly
(`fish script.fish`) or when `source`d into an interactive session,
both confirmed to run straight through with zero pause. Not a gap in
this project's own wiring -- a real, long-standing fish-shell bug.

**Assembly LSP, fully verified**: `textDocument/completion` returned
1301 real candidates (confirmed `"mov"` present among them), full ARM64
mnemonics plus GAS directives (`.cfi_*`, `.p2align`, etc.). Hover on
`mov` returned the complete ISA reference -- every real alias/variant
(scalar, SVE, SIMD, tile-to-vector...), not a stub. Diagnostics on a
genuinely invalid mnemonic correctly fired via both `as` ("unknown
mnemonic") and clang ("unrecognized instruction mnemonic") -- asm-lsp's
documented behavior of trying gcc then clang, confirmed live.

**Assembly debugging: two real bugs found and fixed, not one.** First:
dape's own built-in `gdb` config never listed `asm-mode` in its
`modes` (only C/C++/hare variants) -- added it (see the earlier
`MOUNT_HOST_GUIX`-era commit's dape-config.el change, since folded into
the shared `:program` dolist to stay DRY rather than a separate
`when-let*` block, per direct feedback). Second, deeper bug, found only
by actually trying to launch a real debug session rather than just
checking the `modes` list: `+dape-resolve-cwd`'s fallback
(`dape-command-cwd`, the same broken `project-current` chain already
documented above for Rust/Go/C) resolves to the literal string `"//"`
when *no* project-manifest marker (`Cargo.toml`/`CMakeLists.txt`)
exists anywhere up the directory tree at all -- not just the wrong
root, a genuinely broken one. gdb then silently never finds the
relative `:program "a.out"` at `//a.out`, every breakpoint sits
"pending" forever, and the adapter's own output/events buffers stay
completely empty -- no error surfaces anywhere, it just silently never
runs. Every other language routing through this shared resolver always
has a manifest file (that's the normal case for C/Rust projects);
assembly, having no manifest convention at all, is the first to hit the
"zero markers anywhere" path. Fixed the same way `+dape-lua-cwd`
already handled the identical class of problem for Lua: fall back to
the buffer's own directory instead of trusting the project-root guess
at all, since a manifest-less file shouldn't route through project-root
guessing in the first place.

Confirmed live, full cycle, after both fixes: assembled a real aarch64
ELF with debug symbols (`as -g`), set a breakpoint on `add w2, w0, w1`
via `dape-breakpoint-toggle`, launched dape's `gdb` config -- execution
stopped at exactly that line (confirmed via `dape--overlay-arrow-position`
matching the exact source text), `*dape-info Scope*` showed `w0 5`/`w1
10` (the program's own prior `mov` values, correct before the `add`
executes), stepped over the instruction via `dape-next`, and `w2`
correctly showed `15`. Two regression tests added to `smoketest.bats`
covering both fixes (the `modes` list, and `+dape-resolve-cwd`'s
fallback value directly) rather than relying only on this one manual
verification.

One real methodology trap along the way, worth recording: several
early attempts to drive `dape` non-interactively appeared to hang or
silently fail to launch the target binary. Root cause turned out to be
mostly self-inflicted -- a fresh container's Emacs daemon spends its
first real seconds burning CPU on Doom's own async native-compilation
backlog (`yasnippet`/`smartparens`/`dash`/`evil-collection` .el files
compiling in parallel `emacs -Q --batch` subprocesses), starving the
single-threaded main Emacs of the cycles it needs to process dape's own
async DAP responses -- checking too soon after launching looked exactly
like a real hang. Separately, simulating the *interactive* `M-x dape`
minibuffer prompt via `minibuffer-with-setup-hook` without also sending
a terminating RET left a real stuck recursive-edit; driving it via
`(dape (dape--config-eval 'gdb nil))` directly (bypassing the
interactive prompt machinery entirely) was both simpler and more
reliable for scripted verification.

Full smoketest after all of this: 88/88.

### 2026-07-22/23 — Racket + Rash added, tenth full-support language

`(racket +lsp)` added to `:lang`, between `(python ...)` and `(ruby +lsp)`.
Doom's own `lang/racket/config.el` turned out to be as fully built out as
Guile's own `scheme` module -- a rich localleader map (run, test,
expand-macro variants, send region/definition/last-sexp to the REPL,
visit-definition, docs, logger, profiler, unicode input, paren-shape
cycling), `set-repl-handler!`/`set-lookup-handlers!`, and its own
`set-formatter!` call wiring `raco fmt` into apheleia -- confirmed live
that **zero new elisp files were needed**, matching the "check before
assuming a new `{lang}-keybindings.el` is required" habit this file's own
Guile/Fish/Assembly entries already established.

**Racket install: official installer, not apt** (apt ships 8.18 on 26.04,
several minor versions behind current 9.2 stable). `racket-minimal-9.2-
{aarch64,x86_64}-linux-buster-cs.sh`, sha256-verified against
mirror.racket-lang.org directly (not trusted from any earlier note),
installed via `--unix-style --dest ~/.local/lib/racket --create-dir <
/dev/null` -- confirmed live this installer needs nothing beyond stdin
redirection to run non-interactively, unpacking to a normal `bin/`/
`share/`/`lib/` tree under that dest. `raco pkg install --auto
--skip-installed racket-langserver rash fmt` installs all three from
Racket's own package catalog, no separate toolchain.

**The prior session's "Unexpected EOF" mystery (racket-langserver via a
raw manual `printf | racket --lib racket-langserver` pipe) was fully
resolved: it was crude, hand-rolled Content-Length framing, not a real
langserver bug.** Confirmed live via lsp-mode in a real Emacs buffer:
full server capabilities returned (completion, hover, definitions,
rename, semantic tokens, formatting), no EOF issue at all once a real
LSP client does the handshake instead of a manual pipe.

**Rash (willghatch/racket-rash) went from "flag for explicit go/no-go" to
implemented this session** -- Josiah's call: the maintainer is still
actively using Rash day-to-day, so its ~2.5yr-stale git activity doesn't
indicate the same kind of dormancy scsh's real 20-year abandonment does.
Verified live, not assumed: `#lang rash` files get `racket-mode` via the
same `.rkt` extension (Rash has no separate extension convention -- its
own demo scripts are plain `.rkt` files with `#lang rash` inside), and
racket-langserver's own docs' claim that its analysis is "DrRacket-API-
generic, unverified for Rash specifically" turned out to hold up in
practice: 1732 real completions in a rash buffer, including rash-specific
bindings (`#%shell-pipeline/default-pipeline-starter`,
`#%linea-default-line-macro`), not a degraded/inert connection. Real
Rash pipeline syntax needed correcting mid-session too: `{echo ...}
{wc -c}` (a guess extrapolated from the `in-dir { ... }` block-syntax
example) is wrong -- Rash's actual command syntax is bash-like with no
braces at all (`echo "banana pie" | wc -c`), confirmed directly against
`racket-rash`'s own scribble docs rather than left as an unverified
fixture.

**Two real, non-obvious findings from GUI verification, neither a
Racket-langserver bug:**
1. `apheleia.el` (the actual formatting *engine*, as opposed to
   `apheleia-formatters.el`, which just holds default mode/formatter data
   and loads independently) is lazily autoloaded, and Doom's
   `set-formatter!` -- the only mechanism that adds `racket-mode`'s
   `raco-fmt` mapping to `apheleia-mode-alist`, since raco-fmt isn't one
   of apheleia's own ~100 built-in defaults the way `lua-mode`/`stylua`
   is -- defers its whole body inside `(after! apheleia ...)`. In a
   genuinely fresh session, nothing has forced that engine to load yet,
   so `racket-mode`'s formatter mapping simply doesn't exist until
   *something* (any apheleia-mode-alist-registered format, on any
   buffer) triggers the real load first. This isn't Racket-specific --
   confirmed live it identically blocks Lua's already-working
   `stylua`-via-`+onsave` on a language's very first save of a session
   too -- but it only becomes visible for a language whose formatter
   comes entirely from Doom's own customization rather than apheleia's
   built-in defaults, which is why Racket surfaced it first.
2. Racket's own Doom module claims localleader `f` for
   `racket-fold-all-tests`, not the generic `apheleia-format-buffer`
   every other language in this image binds there -- confirmed live via
   `key-binding`, not assumed from the Guile precedent. Format-on-save
   itself (`(format +onsave)`, global) still works correctly regardless;
   only the manual on-demand "format now" shortcut is unavailable for
   Racket specifically.

**A real, separate infra discovery, unrelated to Racket:** running two
of this repo's `run.sh`-launched IDE containers at once (e.g. this image
alongside `logic-ide`, for genuinely parallel work) collides their Emacs
servers. `run.sh` bind-mounts the *host's real* `XDG_RUNTIME_DIR` into
the container at the identical path (needed for Wayland display
forwarding), and Emacs's own default server socket
(`$XDG_RUNTIME_DIR/emacs/server`) is therefore the *same host file* for
every such container -- whichever one started first keeps the socket,
and every `emacsclient` call against the second container's own name
silently talks to the first container's Emacs instead (confirmed live
via `strace`: `connect()`/`sendto()` succeed, but the "server" never
responds to an unrelated request it has no context for). Symptom looked
exactly like a hung/broken server at first, made more confusing by the
fact that the GUI window itself stayed fully interactive throughout --
because that was a *different* container's Emacs the whole time.

**Actually fixed in `run.sh` itself, not just worked around for this
session** -- Doom already reads an `EMACS_SERVER_NAME` env var before
calling `server-start` (`doom-editor.el`'s own `use-package! server`
block, confirmed directly from source), and `emacsclient` itself reads
a matching `EMACS_SOCKET_NAME` (confirmed via the actual `emacsclient`
binary's own strings) -- no mount redesign needed, and no `--eval`
hackery either (a plain `--eval` on the emacs command line runs *after*
Doom's own init has already called `server-start`, too late to change
anything). `run.sh` now sets both to the container's own `--name` value
(`doom-systems-ide-aarch64`), giving every container using this pattern
a uniquely-named socket in the same shared directory automatically.
Confirmed live with `logic-ide` genuinely running in parallel the whole
time: a bare `emacsclient --eval "(+ 1 1)"` (no `-s` flag) responded
instantly. See AGENTS.md #15 and DECISIONLOG.md for the full reasoning.

**Two real, non-Racket bats bugs found and fixed as a byproduct of
writing Racket's own regression tests, both about test methodology, not
product bugs:**
1. `emacsclient --eval`'s return value is printed via Lisp's `prin1`,
   which backslash-escapes embedded quotes in strings -- a plain-string
   content match against a formatter's output needs to account for that
   (or sidestep it entirely, e.g. via `count-lines`), not compare against
   the literal unescaped text.
2. `+dape-resolve-cwd`'s own regression test (added last session for
   Assembly) asserted the "zero markers found anywhere" fallback using
   `/tmp/smoketest/asm/test.s` -- but `/tmp/smoketest/`'s own
   `CMakeLists.txt` fixture (there for the C/CMake tests) is a real
   ancestor `locate-dominating-file` finds from *any* depth underneath
   it, so that test was silently checking "walks up to the nearest
   CMakeLists.txt," the opposite of its own name and comment. Same root
   class as the `go--is-go-asm`/`c-or-c++-mode` fixture-collision bugs
   already in this file, just via ancestor-directory search instead of
   same-directory sibling contents or same-basename matching. Fixed by
   moving the "zero markers" fixture to a genuinely separate top-level
   root (`/tmp/smoketest-nomarkers/`), not just a deeper subdirectory
   (which wouldn't have helped -- `locate-dominating-file` walks every
   ancestor, not just the immediate parent).

Full smoketest on aarch64 after all of the above: 94/94. x86_64 tree got
the identical Dockerfile/init.el/smoketest.bats source changes mirrored
over, per this project's established pattern, but was **not** rebuilt or
tested this session -- deliberately deferred to the batch x86_64 pass
already planned (see DECISIONLOG.md/ROADMAP.md), same status as Guile's
own x86_64 gap from two days prior.
