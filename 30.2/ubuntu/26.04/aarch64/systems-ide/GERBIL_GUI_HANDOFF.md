# Gerbil integration handoff — 2026-08-05

Branch: `schemes-integration`. Work is **done** — the GUI test below has
passed against the rebuilt image.

## What was diagnosed

The reported editor freeze genuinely occurred from a `gerbil-mode` `hello.ss`
buffer, but `geiser-mode` was not active. Doom's `:lang scheme` localleader map
is attached to `scheme-mode-map`; because `gerbil-mode-map` inherits that map,
`SPC m e d` resolved to `geiser-eval-definition`. With no Geiser REPL, its error
entered Emacs's debugger and a `recursive-edit`, which looked like a frozen
daemon.

This is separate from the already-fixed multi-backend Geiser implementation
prompt hang. The exact-major-mode guard correctly prevents hook-based Geiser
activation in Gerbil; direct inherited keybindings bypassed that guard.

Upstream Gerbil v0.18.2 `gerbil-mode.el` was also inspected directly. Current
upstream master is byte-for-byte unchanged and provides font-lock, indentation,
cmuscheme/gxi REPL commands, and build commands, but no CAPF, Company backend,
Geiser backend, or LSP integration.

## Current implementation

### Evaluation and REPL routing

- `gerbil-keybindings.el` shadows the inherited `SPC m e ...` Geiser subtree
  with gerbil-mode/cmuscheme commands:
  - `e b/B`: reload buffer / reload and switch to REPL
  - `e e`: evaluate last sexp
  - `e d/D`: evaluate definition / evaluate and switch
  - `e r/R`: evaluate region / evaluate and switch
- `gerbil-config.el` adds `+gerbil-reload-current-buffer-and-go` for the
  uppercase buffer command; it genuinely switches instead of sharing a
  misleading no-switch implementation.
- The existing Doom REPL/eval handler registrations remain Gerbil-specific and
  use exact `gerbil-mode` dispatch.

### Scheme/Geiser activation

The pending direct `(add-hook 'scheme-mode-hook #'geiser-mode)` would have
activated Geiser in derived `gerbil-mode` buffers after rebuild. It is now a
private `+geiser--activate-mode-h` hook that calls `geiser-mode` only when
`major-mode` is literally `scheme-mode`. This fixes the intended plain-Scheme
activation gap while keeping Gerbil outside Geiser.

### Completion — deliberately scoped compromise

The user accepted editor-side completion as a pragmatic improvement after
confirming upstream gerbil-mode has no semantic completion support.

`gerbil-config.el` now uses only installed Doom/Company facilities:

- `company-keywords` reuses its existing `scheme-mode` vocabulary and adds the
  real Gerbil top-level declaration `package:`. Gerbil syntax is `package:
  name`, not `(package ...)`.
- `company-dabbrev-code` supplies symbols already present in Gerbil buffers.
- `company-capf` and `company-yasnippet` remain available.
- `company-dabbrev-minimum-length` is buffer-local and set to 3 so short forms
  such as `def` appear.

No keyword catalog is copied into project config, no runtime/global symbol
table is scanned, and completion is not coupled to a running gxi process.
Known ceiling: Company’s Scheme vocabulary itself omits some runtime-valid
forms, notably `define`. The user explicitly accepted this scope rather than
forking Gerbil to build a complete semantic integration now.

GUI observations before the final rebuild confirmed `gr` -> `greet`, `he` ->
`hello`, `de` -> `def`, and `di` -> `displayln`. Automated rebuilt-image checks
confirm both `package:` vocabulary and local-symbol completion.

Flycheck saying "no checker" is expected: Gerbil deliberately has no checker
or LSP integration in this image.

## Style and architecture review

The changes were reviewed against repository-root `AGENTS.md`,
`ELISP-STYLE-GUIDE.md`, `ELISP-ARCHITECTURE-GUIDE.md`,
`DOOM-EMACS-GUIDE.md`, and the neighboring Elisp files.

- Language behavior stays in `gerbil-config.el`; bindings stay in
  `gerbil-keybindings.el`.
- Doom conventions are used: `after!`, `add-hook!`, `map!`, and
  `set-company-backend!`.
- Private hook naming uses a double hyphen; the command consumed by the
  keybinding file is intentionally public.
- Both files use the project-standard lexical-binding header, Commentary/Code
  sections, matching `provide`, and `ends here` footer.
- The discarded prototype used `mapatoms` over process-global Scheme symbol
  properties. It was load-order-dependent and coupled completion to unrelated
  loaded packages; none of that implementation remains.
- aarch64 and x86_64 Gerbil Elisp files are byte-for-byte identical.
- x86_64's Dockerfile previously loaded but did not COPY the two Gerbil files;
  the missing COPY lines are now present. x86_64 has not been rebuilt/tested.

## Verification completed

- `git diff --check`: clean.
- aarch64 image rebuilt successfully from the reviewed source; clean Doom sync
  and native compilation completed without an Elisp error.
- Full smoke suite in a dedicated disposable test container: **114/114 pass**.
  Relevant coverage includes literal Scheme activation, Gerbil mode detection,
  Gerbil eval binding resolution, completion vocabulary/local symbols, and
  Doom loading without error.
- Fresh GUI was launched from the rebuilt image without manually loading host
  files. Live inspection showed:
  - `major-mode`: `gerbil-mode`
  - `geiser-mode`: nil
  - `SPC m e d`: `scheme-send-definition`
  - shipped Company backends include grouped keywords + dabbrev
  - `package:` is a keyword candidate
  - recursion depth: 0

Two earlier GUI disappearances were test-harness errors, not Gerbil crashes:
`smoketest.bats` was run inside the interactive GUI container and terminated
its Emacs daemon. Docker events confirmed the Bats exec exited 137 immediately
before the main Emacs process exited cleanly. Never run Bats inside the GUI
container; use `./run.sh -t` separately.

## Remaining required GUI test

Start a GUI container only if one is not already running:

```bash
cd /home/josiah/Development/personal/automation-engineering/docker-emacs/30.2/ubuntu/26.04/aarch64/systems-ide
rtk proxy ./run.sh -f gerbil
```

Use `/home/josiah/flight-tests/gerbil/hello.ss` and verify:

1. `pa` at column zero offers `package:`; `(byt` offers `bytevector`; `(gr`
   offers `greet`.
2. Put point inside the `greet` definition and press `SPC m e D`.
3. If prompted, start Scheme and accept the `gxi` command.
4. Confirm `*scheme*` opens without Geiser or a debugger recursion.
5. Return to `hello.ss`, put point on the final display form, press
   `SPC m e e`, and confirm the greeting appears in `*scheme*`.
6. Confirm the GUI remains responsive, `(recursion-depth)` returns 0, and no
   recursive-debug `*Backtrace*` buffer appears.

Do not manually load host Elisp into this container: the rebuilt image already
contains the reviewed configuration, and the test must validate shipped state.

## Worktree caution

The worktree was already dirty before this investigation. In particular,
changes to the aarch64 Scheme fixtures, `scheme-config.el`, and broader
multi-backend portions of `smoketest.bats` predated this work and belong to the
user. Review the complete diff, but do not discard or attribute all dirty files
to this Gerbil change.
