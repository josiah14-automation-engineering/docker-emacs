# Grokking Doom Emacs

A navigational guide to Doom Emacs architecture, configuration, and internals — for humans and AI agents alike. This document provides enough overview to understand how Doom works, then points to the right primary sources for specifics. Every section names the concrete place to look next.

> **Companion documents:**
> - `GNU-EMACS-GUIDE.md` — foundational Emacs concepts this builds on
> - `ELISP-STYLE-GUIDE.md` — low-level elisp conventions
> - `ELISP-ARCHITECTURE-GUIDE.md` — architectural patterns

---

## What Doom Is (and Is Not)

Doom Emacs is a configuration framework layered over vanilla GNU Emacs. It is **not** a fork or a separate application — it is a set of elisp that runs inside Emacs and manages the loading, configuration, and interaction of packages on your behalf.

What Doom adds over vanilla Emacs:

- A **module system** that groups packages and configuration into toggleable units
- A **CLI tool** (`doom`) for managing the installation outside of Emacs
- A set of **macros** (`after!`, `use-package!`, `map!`, etc.) that make configuration ergonomic
- **straight.el** as the underlying package manager (replacing `package.el`)
- Opinionated defaults: Evil mode (Vim keybindings), a leader-key system, which-key, LSP, and a curated set of modules enabled by default
- A startup performance strategy: lazy loading, AOT compilation, autoload file generation

What Doom does **not** do:

- It does not prevent you from writing vanilla Emacs Lisp anywhere
- It does not sandbox your config from vanilla Emacs internals
- It does not enforce the architecture — you can ignore Doom's macros and call raw Emacs APIs throughout

**Doom's GitHub:** [doomemacs/doomemacs](https://github.com/doomemacs/doomemacs)
**Official modules repo:** [doomemacs/modules](https://github.com/doomemacs/modules)
**Community modules:** [doomemacs/modules-contrib](https://github.com/doomemacs/modules-contrib)

> **Sources:**
> - [Doom Emacs Documentation — docs.doomemacs.org](https://docs.doomemacs.org/latest/)
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)

---

## Environment Variables and Directory Layout

Doom uses three environment variables to separate concerns. Understanding them is essential before anything else.

| Variable | Default | Purpose |
|---|---|---|
| `$EMACSDIR` | `~/.config/emacs` or `~/.emacs.d` | Doom's own installation — the framework code |
| `$DOOMDIR` | `~/.config/doom` or `~/.doom.d` | Your private config — `init.el`, `config.el`, `packages.el` |
| `$DOOMLOCALDIR` | `$EMACSDIR/.local` | Generated artifacts: byte-compiled packages, autoloads, straight repos |

**Critical rule:** `$DOOMDIR` is safe to sync across machines (it is your config). `$EMACSDIR` is **not** safe to sync — `.local/` contains baked-in absolute paths and machine-specific byte-code.

### In this Docker project

| Emacs version | OS | IDEs |
|---|---|---|
| 27.2 | Ubuntu 20.04 | Python, Scala |
| 28.1 | Ubuntu 20.04, 22.04 | Python, Scala, 47deg-Scala |
| 29.2 | Ubuntu 22.04, 24.04 (x86_64 + aarch64); Alpine 3.20.2 | Python, Haskell, Mercury |
| 30.2 | Ubuntu 24.04 (x86_64) | Mercury |

The config files (`init.el`, `config.el`, `packages.el`) in each IDE subdirectory map directly to `$DOOMDIR`. They are copied into the container and processed by `doom sync` at image build time. The build scripts pass `USERNAME`, `USER_UID`, `USER_GID`, `FULLNAME`, and `EMAIL` as build args; placeholders in `config.el` (`<full-name>`, `<email-address>`, `<username>`) are substituted at build time.

> **Sources:**
> - [Doom FAQ — docs.doomemacs.org/latest/faq](https://docs.doomemacs.org/latest/faq)
> - [doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)

---

## The Three Config Files

Every `$DOOMDIR` contains exactly three files that Doom treats specially:

### `init.el` — Module selection

Controls which Doom modules are active. Contains the `doom!` block. Changing this file requires `doom sync` + Emacs restart to take effect. Do **not** put general configuration here — only module declarations.

```elisp
;;; init.el -*- lexical-binding: t; -*-

(doom! :completion
       (company +auto)
       vertico

       :ui
       doom
       modeline
       treemacs

       :lang
       (python +lsp +pyenv)
       ...)
```

The in-project `init.el` files (e.g., `28.1/ubuntu/22.04/python-ide/init.el`) are the canonical examples to read in this repo.

### `config.el` — Personal configuration

Evaluated **after all modules have finished loading**. This is where you put everything: keybindings, theme, font, mode hooks, package reconfiguration. Does **not** require `doom sync` after changes — just restart Emacs (or `M-x doom/reload`).

### `packages.el` — Extra package declarations

Declares additional packages to install (not provided by any enabled module) or overrides existing package recipes/pins. Changing this file requires `doom sync`.

> **Sources:**
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)
> - [Doom FAQ](https://docs.doomemacs.org/latest/faq)

---

## Boot and Load Sequence

Understanding load order prevents an entire class of "my config isn't applying" bugs.

```
1. early-init.el          ← Doom's bootstrap; runs before Emacs UI or package.el
2. Core Doom libs load    ← lisp/doom.el, lisp/doom-start.el
3. Profile init           ← Generated profile file (pre-computed autoloads, metadata)
4. Module :init phase     ← Each enabled module's early setup runs, in doom! order
5. Packages available     ← straight.el has loaded all packages
6. Module :config phase   ← Each enabled module's main config.el runs
7. $DOOMDIR/config.el     ← YOUR config runs last, after all modules
```

**Practical consequence:** Your `config.el` runs after every module. This means you can safely reconfigure anything a module set up — but it also means any code that needs to run *before* a module must use hooks or be placed in the module's own files.

**Two-phase module loading:** Each Doom module has an `:init` phase (early, before packages are fully available) and a `:config` phase (after packages load). Module files named `init.el` run in the first phase; `config.el` runs in the second. This is why `after!` and `use-package!` are the right tools in your private config — they defer evaluation until the relevant package is loaded.

> **Sources:**
> - [Initialization & Boot Sequence — DeepWiki](https://deepwiki.com/doomemacs/doomemacs/2.1-init-and-load-sequence)
> - [doomemacs/early-init.el — GitHub](https://github.com/doomemacs/doomemacs/blob/master/early-init.el)
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)

---

## The Module System

### Structure of a module

A module is a directory at `$DOOMDIR/modules/CATEGORY/NAME/` (for private modules) or in the Doom modules repo. It may contain:

| File | Purpose |
|---|---|
| `packages.el` | Declares packages the module installs |
| `init.el` | Early phase setup (pre-package-load) |
| `config.el` | Main configuration (post-package-load) |
| `autoloads.el` | Functions available without loading the module |
| `doctor.el` | Checks run by `doom doctor` |
| `README.org` | Module documentation (rendered in Doom's help system) |

### Module categories

The `doom!` block organizes modules by category. Categories in declaration order:

| Category | Purpose |
|---|---|
| `:input` | Input methods (Chinese, Japanese, custom layouts) |
| `:completion` | Completion frameworks: `vertico`, `company`, `helm`, `ivy` |
| `:ui` | Visual/interface modules: themes, modeline, treemacs, workspaces |
| `:editor` | Editing behaviour: evil, snippets, format, fold, multiple-cursors |
| `:emacs` | Core Emacs subsystems: dired, ibuffer, undo, vc |
| `:term` | Terminal emulators: eshell, vterm, shell |
| `:checkers` | Syntax and spell checking: syntax (flycheck), spell |
| `:tools` | External tool integrations: lsp, magit, docker, direnv |
| `:os` | OS-specific: macos, tty |
| `:lang` | Language support modules |
| `:email` | Email clients: mu4e, notmuch |
| `:app` | Complex application modules: calendar, rss, irc |
| `:config` | Doom's own config modules (always last): `literate`, `default` |

### Module flags

Flags modify a module's behaviour. They appear as `+flag-name` in the `doom!` block:

```elisp
(python +lsp +pyenv +poetry)  ; python module with three flags enabled
```

To see what flags a module supports: in `init.el`, place cursor on the module name and press `K` (Evil) or `C-c c k` (non-Evil). To jump to the module's source: press `gd` (Evil) or `C-c c d`.

### Writing a private module

Create `$DOOMDIR/modules/CATEGORY/NAME/` and add `:CATEGORY NAME` to your `doom!` block. A private module follows the same file structure as an official module.

```
~/.config/doom/modules/
└── tools/
    └── mercury/
        ├── config.el
        ├── packages.el
        └── autoloads.el
```

> **Sources:**
> - [Doom Modules Documentation — doomemacs/docs/modules.org](https://github.com/doomemacs/doomemacs/blob/master/docs/modules.org)
> - [How to Write Your Own Modules — Doom Discourse](https://discourse.doomemacs.org/t/how-to-write-your-own-modules/86)
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)

---

## Core Macros Reference

These are the tools you use in `config.el`. Understanding what each one does (and when to reach for it) is the most important practical knowledge in Doom.

### `after!` — deferred configuration

```elisp
(after! PACKAGE-OR-FEATURE
  BODY...)
```

Evaluates `BODY` after `PACKAGE-OR-FEATURE` has loaded. This is a wrapper around `with-eval-after-load`. Use this for reconfiguring anything a module already set up — it guarantees your code runs after Doom's defaults, not before them.

```elisp
(after! lsp-mode
  (setq lsp-enable-symbol-highlighting nil))

;; List = AND: body runs only after ALL listed packages have loaded
(after! (evil magit)
  (evil-define-key 'normal magit-mode-map ...))

;; :or / :any = OR: body runs after EITHER package loads
(after! (:or evil-collection evil)
  (my-evil-setup))
```

`after!` expands to nested `with-eval-after-load` calls. The list AND form nests them so the body only fires once both have loaded. The `:or`/`:any` form fires on whichever loads first.

**When not to use it:** If a package is always loaded at startup (not lazy-loaded), `after!` is harmless but unnecessary. For packages that may not be installed at all, check `(featurep 'package-name)` instead.

### `use-package!` — package declaration and configuration

```elisp
(use-package! PACKAGE
  :after FEATURE
  :hook (MODE . FUNCTION)
  :init BEFORE-LOAD-CODE
  :config AFTER-LOAD-CODE
  ...)
```

Doom's wrapper around `use-package`. Identical semantics to vanilla `use-package` but integrated with Doom's module system — if a package is disabled, its `use-package!` blocks are silently skipped. Use this when you need the full `use-package` lifecycle (`:init`, `:config`, `:hook`, `:bind`). For simple post-load configuration, prefer `after!` — it is less ceremony.

### `map!` — keybinding

```elisp
(map! :leader
      :desc "Compile buffer" "c c" #'mercury-ide/compile-buffer)

(map! :after evil
      :map mercury-mode-map
      :n "gd" #'mercury-ide/jump-to-definition
      :n "K"  #'mercury-ide/show-docs)
```

Powered by `general.el`. Handles leader keys, Evil state prefixes (`:n` normal, `:i` insert, `:v` visual, `:m` motion, `:o` operator, `:e` Emacs), and `which-key` descriptions via `:desc`. The `:leader` prefix binds under `SPC`; `:localleader` binds under `SPC m` (or `,` in Evil).

**Key state prefixes in `map!`:**

| Prefix | Evil state |
|---|---|
| `:n` | Normal |
| `:i` | Insert |
| `:v` | Visual |
| `:o` | Operator |
| `:m` | Motion |
| `:e` | Emacs state |
| `:g` | Global (all states) |

> Keybinding system deep-dive: [DeepWiki — Keybinding System](https://deepwiki.com/doomemacs/doomemacs/3.1-keybinding-system)

### `setq!` — setting variables with custom setters

```elisp
(setq! lsp-headerline-breadcrumb-enable t)
```

Like `setq`, but triggers `defcustom` setter functions. Use this for variables defined with `defcustom` that have `:set` handlers — using plain `setq` on them bypasses the setter and may leave the system in an inconsistent state. When in doubt, `setq!` is safe to use anywhere you would use `setq`.

### `add-hook!` — adding hooks with Doom's syntax sugar

```elisp
;; Single hook, single function
(add-hook! 'mercury-mode-hook #'mercury-ide/setup)

;; Multiple hooks, single function
(add-hook! '(mercury-mode-hook prolog-mode-hook) #'my-logic-setup)

;; Single hook, multiple functions
(add-hook! 'mercury-mode-hook
  #'mercury-ide/setup
  #'flycheck-mode
  #'company-mode)
```

Doom's wrapper around `add-hook` with nicer syntax for multiple hooks/functions. Functionally equivalent to vanilla `add-hook`; the advantage is terseness.

### `load!` — loading additional elisp files

```elisp
(load! "extra-config")         ; loads $DOOMDIR/extra-config.el
(load! "modules/my-helpers")   ; relative to current file
```

Use this to split a large `config.el` into multiple files without managing `load-path` manually.

> **Sources:**
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)
> - [Doom FAQ](https://docs.doomemacs.org/latest/faq)
> - [Doom Discourse — Style](https://discourse.doomemacs.org/t/style/3723)

---

## Package Management with `straight.el`

Doom uses [straight.el](https://github.com/radian-software/straight.el) instead of `package.el`. Straight is a purely functional package manager — it clones package repos from source rather than downloading pre-built `.tar` files, which gives you pinning, recipe overrides, and local package development.

### `package!` — the declaration macro

In `packages.el`:

```elisp
;; Install a package not in any enabled module
(package! some-package)

;; Install from a specific source (straight.el recipe format)
(package! mercury-mode
  :recipe (:host github :repo "sebdah/mercury-mode"))

;; Pin to a specific commit
(package! some-package :pin "abc123def456")

;; Disable a package that a module would otherwise install
(package! package-i-dont-want :disable t)
```

After any change to `packages.el`, run `doom sync`.

### Recipe format

Straight recipes are plists:

```elisp
:recipe (:host github        ; or gitlab, sourcehut, nil
         :repo "user/repo"
         :branch "main"
         :files ("*.el" "src/*.el"))
```

Full recipe format reference: [straight.el README — The Recipe Format](https://github.com/radian-software/straight.el#the-recipe-format)

### Pinning strategy

Doom's own modules pin packages to specific commits for reproducibility. In the Docker context, pinning is especially valuable — an image build is deterministic only if package versions are fixed.

```elisp
;; In packages.el
(package! lsp-mode :pin "a1b2c3d4")
```

The `unpin!` macro removes a pin if you want to track HEAD:
```elisp
(unpin! lsp-mode)
```

> **Sources:**
> - [straight.el — GitHub](https://github.com/radian-software/straight.el)
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)
> - [DeepWiki — Package Management](https://deepwiki.com/doomemacs/doomemacs/3.2-package-management)

---

## Keybinding System

### Leader keys

| Context | Leader | Local leader |
|---|---|---|
| Evil normal/visual state | `SPC` | `SPC m` or `,` |
| Evil insert state | `M-SPC` | `M-SPC m` |
| Non-Evil / Emacs state | `C-c` | `C-c m` |

The leader key system is powered by `general.el`. Doom pre-binds a large map under `SPC` — use `which-key` (press `SPC` and wait) to explore it.

### Useful built-in leader bindings to know

| Binding | Action |
|---|---|
| `SPC h d h` | Open Doom's documentation |
| `SPC h d m` | Module index |
| `SPC h d r` | Reload Doom (equivalent to `doom/reload`) |
| `SPC f p` | Find file in `$DOOMDIR` |
| `SPC f e` | Find file in `$EMACSDIR` |
| `SPC :` | Run any M-x command |
| `SPC b b` | Switch buffer |
| `SPC w` prefix | Window management |
| `SPC p` prefix | Project commands (projectile) |
| `SPC g` prefix | Git / Magit |

### In-module navigation

| Binding | Action |
|---|---|
| `K` (on a symbol) | View documentation |
| `gd` (on a symbol) | Jump to definition |
| Both work on module names in `init.el` | |

> **Sources:**
> - [Keybinding Reference Sheet — Doom Discourse](https://discourse.doomemacs.org/t/keybind-reference-sheet/49)
> - [Keybinding System — DeepWiki](https://deepwiki.com/doomemacs/doomemacs/3.1-keybinding-system)
> - [Practicalli Doom Emacs — Bindings](https://practical.li/doom-emacs/install/bindings/)

---

## CLI Reference (`doom` command)

The `doom` CLI runs outside Emacs and manages the installation. Run from the shell.

| Command | When to run | What it does |
|---|---|---|
| `doom sync` | After changing `init.el` or `packages.el` | Installs/removes packages, regenerates autoloads |
| `doom upgrade` | When you want to update Doom itself | Updates Doom framework + packages |
| `doom doctor` | When something is broken | Diagnoses common config/env problems |
| `doom env` | After changing your shell environment | Scrapes shell env into a file Emacs loads at startup |
| `doom build` | Rarely needed manually | Byte-compiles and symlinks packages |
| `doom purge` | Occasionally, to clean up | Removes orphaned packages and compacts repos |
| `doom info` | When filing a bug report | Dumps system info as markdown |

**Most common workflow:**

```sh
# After editing init.el or packages.el:
doom sync

# After pulling Doom updates:
doom upgrade

# When Emacs behaves unexpectedly:
doom doctor
```

In the Docker images in this project, `doom sync` runs during the image build (in the Dockerfile, after config files are copied in). The `doom env` step may also be needed if the container's `PATH` differs from the build environment's.

> **Sources:**
> - [CLI Tools & Commands — DeepWiki](https://deepwiki.com/doomemacs/doomemacs/1.2-cli-tools-and-commands)
> - [Doom FAQ](https://docs.doomemacs.org/latest/faq)

---

## Key Doom Variables

Doom exposes a set of variables you can set in `config.el` before their respective features load.

### Fonts

```elisp
(setq doom-font              (font-spec :family "SauceCodePro Nerd Font" :size 16 :weight 'medium)
      doom-variable-pitch-font (font-spec :family "sans" :size 13)
      doom-big-font           (font-spec :family "SauceCodePro Nerd Font" :size 24))
```

### Theme

```elisp
(setq doom-theme 'doom-solarized-dark)
```

Available themes: `doom-one`, `doom-solarized-dark`, `doom-nord`, `doom-gruvbox`, etc. Full list: `M-x doom/describe-theme` or browse `~/.config/emacs/modules/ui/doom/themes/`.

### Line numbers

```elisp
(setq display-line-numbers-type 'relative)  ; relative
(setq display-line-numbers-type t)          ; absolute
(setq display-line-numbers-type nil)        ; disabled
```

### Other commonly-set Doom variables

| Variable | Purpose |
|---|---|
| `doom-leader-key` | Leader key (default `"SPC"`) |
| `doom-localleader-key` | Local leader key (default `"SPC m"`) |
| `doom-modeline-*` | Modeline appearance options |
| `+format-on-save-enabled-modes` | Modes where format-on-save applies |

> **Sources:**
> - [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)

---

## Navigating Doom's Source

Doom's source is the authoritative reference. Knowing where things live is more useful than any secondary documentation.

### Key locations (inside `$EMACSDIR`)

```
$EMACSDIR/
├── early-init.el               ← Bootstrap entry point
├── lisp/
│   ├── doom.el                 ← Core Doom definitions
│   ├── doom-start.el           ← Startup sequence
│   ├── doom-modules.el         ← Module system
│   ├── doom-packages.el        ← Package management layer
│   └── doom-keybinds.el        ← map! and leader key system
├── modules/                    ← Official modules (or symlinked from doomemacs/modules)
│   ├── lang/python/
│   │   ├── config.el           ← Python module config
│   │   ├── packages.el         ← Python module packages
│   │   └── README.org          ← Python module docs
│   └── ...
└── bin/doom                    ← CLI entry point
```

### Finding things in practice

1. **Press `K`** on any symbol in Emacs to open its documentation
2. **Press `gd`** to jump to a symbol's definition — works on Doom macros too
3. **`SPC h d m`** — browse the module index with documentation
4. **`M-x doom/describe-module`** — describe a specific module
5. **`doom doctor`** — surface environment/config problems
6. **GitHub search** in [doomemacs/doomemacs](https://github.com/doomemacs/doomemacs) for source-level answers
7. **DeepWiki** at [deepwiki.com/doomemacs/doomemacs](https://deepwiki.com/doomemacs/doomemacs) for AI-indexed navigation of the codebase

> **Sources:**
> - [Doom Emacs GitHub — doomemacs/doomemacs](https://github.com/doomemacs/doomemacs)
> - [DeepWiki — doomemacs/doomemacs](https://deepwiki.com/doomemacs/doomemacs)

---

## Common Tasks: Where to Look

| Task | Where to look |
|---|---|
| Enable/disable a module | `init.el` → `doom!` block; then `doom sync` |
| Add a module flag | `init.el` → `(module +flag)`; then `doom sync` |
| Reconfigure a package | `config.el` → `(after! package ...)` |
| Install a new package | `packages.el` → `(package! name)`; then `doom sync` |
| Override a package recipe | `packages.el` → `(package! name :recipe ...)`; then `doom sync` |
| Pin a package | `packages.el` → `(package! name :pin "sha")`; then `doom sync` |
| Add a keybinding | `config.el` → `(map! ...)` |
| Add a hook | `config.el` → `(add-hook! ...)` |
| Set a font | `config.el` → `(setq doom-font ...)` |
| Change theme | `config.el` → `(setq doom-theme '...)` |
| Write a private module | `$DOOMDIR/modules/cat/name/`; add `:cat name` to `doom!` |
| Debug something broken | `doom doctor`; then check `*Messages*` buffer |
| Find what a module does | `K` on module name in `init.el`, or read its `README.org` |
| Find where a module's config lives | `gd` on module name in `init.el` |
| Understand load order | Read `lisp/doom-start.el` in `$EMACSDIR` |
| Understand how `map!` works | Read `lisp/doom-keybinds.el` in `$EMACSDIR` |

---

## Doom-Specific Conventions in This Project

These conventions apply specifically to the IDE configs in this Docker project:

### Placeholder substitution

`config.el` files contain `<full-name>`, `<email-address>`, and `<username>` placeholders that are substituted at Docker build time using `build.sh` args. Never hardcode these values.

### Build-time `doom sync`

`doom sync` runs inside the Dockerfile after config files are copied in, ensuring autoloads are generated and packages installed for the specific module set defined in `init.el`. Changes to module selection require rebuilding the Docker image.

### AOT compilation

All images in this project compile Emacs with `--with-native-compilation` explicitly set. Native compilation behavior by version:

- **27.2** — not available; byte-compilation only
- **28.1** — native compilation opt-in via `--with-native-compilation`; available in these images
- **29.2** — same as 28.1; native compilation available when flag is set
- **30.2** — native compilation enabled by default when `libgccjit` is present

The `doom sync` step includes native compilation of installed packages. First startup after a build may still trigger some JIT compilation of deferred forms — this is expected and not an error.

### No LSP for Mercury

The Mercury IDE does not use an LSP server (none exists with reliable support). The `:tools lsp` module may be enabled but `lsp-mode` should not be configured to activate in `mercury-mode`. Use `flycheck` with `mmc` as the checker instead.

---

## Master Reference List

### Official Doom documentation
- [Doom Emacs Documentation](https://docs.doomemacs.org/latest/)
- [Doom Emacs FAQ](https://docs.doomemacs.org/latest/faq)
- [Getting Started — doomemacs/docs/getting_started.org](https://github.com/doomemacs/doomemacs/blob/master/docs/getting_started.org)
- [Modules Documentation — doomemacs/docs/modules.org](https://github.com/doomemacs/doomemacs/blob/master/docs/modules.org)
- [doomemacs/doomemacs — GitHub](https://github.com/doomemacs/doomemacs)
- [doomemacs/modules — GitHub](https://github.com/doomemacs/modules)
- [doomemacs/modules-contrib — GitHub](https://github.com/doomemacs/modules-contrib)

### DeepWiki (AI-indexed codebase navigation)
- [doomemacs/doomemacs — DeepWiki root](https://deepwiki.com/doomemacs/doomemacs)
- [Initialization & Boot Sequence](https://deepwiki.com/doomemacs/doomemacs/2.1-init-and-load-sequence)
- [Keybinding System](https://deepwiki.com/doomemacs/doomemacs/3.1-keybinding-system)
- [Package Management](https://deepwiki.com/doomemacs/doomemacs/3.2-package-management)
- [CLI Tools & Commands](https://deepwiki.com/doomemacs/doomemacs/1.2-cli-tools-and-commands)
- [Evil Mode Integration](https://deepwiki.com/doomemacs/doomemacs/5-evil-mode-integration)
- [Completion Frameworks](https://deepwiki.com/doomemacs/doomemacs/6-completion-frameworks)

### Community resources
- [Doom Emacs Discourse](https://discourse.doomemacs.org/)
- [Doom Discourse — Style](https://discourse.doomemacs.org/t/style/3723)
- [Doom Discourse — How to Write Your Own Modules](https://discourse.doomemacs.org/t/how-to-write-your-own-modules/86)
- [Doom Discourse — Keybind Reference Sheet](https://discourse.doomemacs.org/t/keybind-reference-sheet/49)
- [Practicalli Doom Emacs — Bindings](https://practical.li/doom-emacs/install/bindings/)

### Package management
- [straight.el — GitHub](https://github.com/radian-software/straight.el)

### Secondary reading
- [Doom Emacs for Newbies — Justin DeMaris / Medium](https://medium.com/urbint-engineering/emacs-doom-for-newbies-1f8038604e3b)
- [My Doom Emacs Configuration with Commentary — zzamboni.org](https://zzamboni.org/post/my-doom-emacs-configuration-with-commentary/)
