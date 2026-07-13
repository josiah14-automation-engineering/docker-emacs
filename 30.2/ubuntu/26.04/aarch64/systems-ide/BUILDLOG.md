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
