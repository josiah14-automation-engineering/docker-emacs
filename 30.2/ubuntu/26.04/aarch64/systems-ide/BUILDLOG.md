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
