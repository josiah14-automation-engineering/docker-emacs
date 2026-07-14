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
