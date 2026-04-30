# Grokking GNU Emacs

A navigational guide to Emacs architecture, core concepts, and internals — for humans and AI agents. This document explains how Emacs actually works at the level needed to write meaningful configuration and extensions, then points to the primary sources for specifics. Every claim is grounded in a verifiable source.

> **Companion documents:**
> - `DOOM-EMACS-GUIDE.md` — Doom-specific layer on top of this
> - `ELISP-STYLE-GUIDE.md` — coding conventions
> - `ELISP-ARCHITECTURE-GUIDE.md` — architectural patterns

---

## What Emacs Is

GNU Emacs is a **Lisp machine** that happens to be good at editing text. Its architecture has two layers:

1. **A C core** — the interpreter, the memory allocator, the display engine, I/O, and process management. This is the part you do not touch.
2. **An Emacs Lisp runtime** — everything above the C core, including most of Emacs's own features (dired, org-mode, font-lock, the help system, the package manager), is written in Emacs Lisp and is fully readable, modifiable, and replaceable at runtime.

The practical consequence: almost everything in Emacs is a Lisp value, and almost everything can be inspected, redefined, and extended without restarting. This is not a scripting layer bolted onto an editor; the editor *is* the Lisp machine.

**Emacs version notes for this project:**

| Version | OS | IDEs |
|---|---|---|
| 27.2 | Ubuntu 20.04 | Python, Scala |
| 28.1 | Ubuntu 20.04, 22.04 | Python, Scala, 47deg-Scala |
| 29.2 | Ubuntu 22.04, 24.04 (x86_64 + aarch64); Alpine 3.20.2 | Python, Haskell, Mercury |
| 30.2 | Ubuntu 24.04 (x86_64) | Mercury |

Notable per-version features relevant to this project:
- **28.1** — native compilation available via `--with-native-compilation` (opt-in at build time)
- **29.2** — tree-sitter built-in (`--with-tree-sitter`); native compilation more prominent; `use-package` built-in
- **30.2** — native compilation enabled by default when `libgccjit` is present; additional tree-sitter language modes

**Primary references:**
- [GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/emacs.html) — user-level reference
- [GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/elisp.html) — programmer's reference; the authoritative source for everything in this guide
- [An Introduction to Programming in Emacs Lisp](https://www.gnu.org/software/emacs/manual/eintr.html) — gentler entry point to the Lisp side
- [Mastering Emacs](https://www.masteringemacs.org/) — best secondary resource; accurate and well-indexed

---

## The Core Data Model

Five objects underlie nearly everything in Emacs. Understanding them precisely eliminates most confusion about how the system behaves.

### Buffers

A buffer is the primary container for text and state. Every piece of text Emacs works with lives in a buffer — files, shell output, help pages, compilation results, even temporary scratch data. A buffer may or may not be associated with a file on disk.

Key properties of a buffer:
- Has a unique name (a string)
- Has a **point** — the cursor position, an integer giving a position between two characters
- Has a **mark** — a second position used to define the region
- Has a set of **buffer-local variables** — each buffer can have its own value of any variable
- Has exactly one **major mode** active at any time
- Has zero or more **minor modes** active
- Has its own **local keymap** from its major mode

A buffer is *not* the same as a window. Many buffers can exist without being displayed. One buffer can be shown in multiple windows simultaneously. The current buffer (`current-buffer`) is the buffer where elisp operations apply by default, which is not necessarily the buffer visible in the selected window.

> **Source:** [Buffer Basics — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Basics.html)

### Windows

A window is a display area that shows one buffer. Windows tile within frames — they never overlap. A window tree organizes all windows on a frame: leaf nodes are live windows showing buffers; internal nodes are container windows organizing the layout.

Critical distinction: **switching a buffer does not change the window layout.** You change which buffer a window displays; the window itself persists. This is why `switch-to-buffer` and `display-buffer` behave differently — one switches the current window's buffer, the other finds or creates a window for the buffer according to `display-buffer-alist` rules.

> **Source:** [Windows — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Windows.html)

### Frames

A frame is a top-level GUI window (what your OS calls a "window"). Each frame contains a window tree. You can have multiple frames, each showing different windows and buffers. In terminal Emacs, there is typically one frame that occupies the terminal.

> **Source:** [Frames — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Frames.html)

### Point, Mark, and Region

**Point** is the cursor position — an integer between 1 and `(point-max)`. It sits *between* characters, not on them. Position 1 is before the first character; `(point-max)` is after the last.

**Mark** is a saved position. The **region** is the text between point and mark. The region is used by commands that operate on a selection.

**Markers** are objects that track a buffer position even as text is inserted or deleted around them. When you need to save a position and come back to it after modifying the buffer, use a marker, not an integer position.

> **Sources:**
> - [Point — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Point.html)
> - [Markers — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Markers.html)

---

## Text Representation: Properties, Overlays, and Font-Lock

Emacs has three mechanisms for annotating text with display or semantic information. Choosing the wrong one causes subtle bugs.

### Text Properties

Text properties are stored directly on the characters in the buffer. They travel with the text when it is copied. Changing text properties marks the buffer as modified and creates an undo entry.

Use text properties for:
- Semantic annotations that are part of the buffer content
- Properties that should survive copy-paste
- Font-lock (which uses text properties internally)

Key functions: `put-text-property`, `get-text-property`, `propertize`, `add-text-properties`

> **Source:** [Text Properties — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Text-Properties.html)

### Overlays

Overlays are separate objects attached to buffer positions via markers. They are **not** part of the buffer text — they do not travel with copied text, do not mark the buffer as modified, and are not recorded in the undo list. They take display priority over text properties.

Use overlays for:
- Temporary visual effects (highlight current match, error underline, lint indicator)
- Annotations that should not affect buffer-modified state
- Dynamic display that gets added and removed frequently

Key functions: `make-overlay`, `overlay-put`, `overlay-get`, `delete-overlay`, `overlays-at`

> **Sources:**
> - [Overlays — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Overlays.html)
> - [EmacsWiki — Emacs Overlays](https://www.emacswiki.org/emacs/EmacsOverlays)

### Font-Lock

Font-lock is the syntax highlighting system. It operates by running a set of regexps (or tree-sitter queries in Emacs 29+) against buffer text and applying `face` text properties to the results. It is implemented as a minor mode (`font-lock-mode`) that is enabled by default in most major modes.

To add syntax highlighting to a major mode, set `font-lock-defaults` as a buffer-local variable in the mode's setup function.

From Emacs 29+, tree-sitter-based major modes (suffixed `-ts-mode`) use tree-sitter grammar libraries for more accurate, incremental highlighting instead of regexp-based rules.

**JIT-lock:** Font-lock uses just-in-time locking (`jit-lock`) to fontify only the visible portions of the buffer on demand, rather than fontifying the whole buffer at once. This keeps large-file performance acceptable.

> **Sources:**
> - [Font Lock Mode — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Font-Lock-Mode.html)
> - [How to Get Started with Tree-Sitter — Mastering Emacs](https://www.masteringemacs.org/article/how-to-get-started-tree-sitter)

---

## The Mode System

### Major Modes

Every buffer has exactly one active major mode. A major mode defines:
- A **local keymap** (`NAME-mode-map`) — key bindings specific to this mode
- A **syntax table** — what characters are word constituents, string delimiters, etc.
- Buffer-local variable settings — `indent-tabs-mode`, `comment-start`, tab width, etc.
- `font-lock-defaults` — syntax highlighting rules
- A **mode hook** (`NAME-mode-hook`) — run at the end of mode activation

Activating a major mode calls the mode function (e.g., `python-mode`). That function sets everything above and runs the mode hook last.

Use `define-derived-mode` to define a new major mode that inherits from an existing one. It wires up the keymap inheritance, hook chain, and mode function boilerplate automatically.

```elisp
(define-derived-mode mercury-mode prog-mode "Mercury"
  "Major mode for editing Mercury source files."
  (setq-local comment-start "% ")
  (setq-local indent-tabs-mode nil))
```

> **Source:** [Major Mode Conventions — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Major-Mode-Conventions.html)

### Minor Modes

Minor modes can be active in any buffer alongside the major mode. They toggle additional behaviour: line numbers, spell checking, auto-completion, LSP, etc. Multiple minor modes can be active simultaneously.

Use `define-minor-mode` to define one. It creates the toggle function, the variable tracking state, a keymap, and a mode hook.

```elisp
(define-minor-mode mercury-ide-mode
  "Minor mode for Mercury IDE features."
  :lighter " Hg"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c C-c") #'mercury-ide/compile-buffer)
            map))
```

> **Sources:**
> - [Minor Mode Conventions — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Minor-Mode-Conventions.html)
> - [Defining Minor Modes — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Minor-Modes.html)
> - [How to Make an Emacs Minor Mode — null program](https://nullprogram.com/blog/2013/02/06/)

---

## The Keymap System

### Lookup order

When you press a key, Emacs resolves it by searching keymaps in this priority order (highest to lowest):

1. `overriding-terminal-local-map` — transient/modal maps (takes absolute precedence)
2. `overriding-local-map` — rarely used; overrides everything below it
3. **`keymap` text or overlay property at point** — keymaps embedded in buffer text
4. **`emulation-mode-map-alists`** — used by packages like Evil for Vim emulation
5. **`minor-mode-overriding-map-alist`** — minor mode maps that should override major mode
6. **`minor-mode-map-alist`** — keymaps of all active minor modes
7. **Buffer's local keymap** (`current-local-map`) — the major mode's keymap
8. **`global-map`** — the global keymap; fallback for everything

**Critical implication:** minor mode keymaps override the major mode's local keymap. If a minor mode binds a key that the major mode also binds, the minor mode wins. This is why Evil mode can override all standard Emacs bindings — it operates at level 4/5.

### Keymap types

- **Sparse keymap** (`make-sparse-keymap`) — a list; efficient when few bindings
- **Full keymap** (`make-keymap`) — a vector + list; efficient when many bindings
- **Prefix keymap** — a keymap stored as the binding of a prefix key (e.g., `C-x` maps to a keymap)

### Defining keybindings

```elisp
;; Global
(global-set-key (kbd "C-c m c") #'mercury-ide/compile-buffer)

;; In a mode's keymap
(define-key mercury-mode-map (kbd "C-c C-c") #'mercury-ide/compile-buffer)

;; Remove a binding
(define-key some-map (kbd "C-c C-z") nil)
```

In Doom, prefer `map!` over direct `define-key` calls. In vanilla Emacs or module code where Doom isn't guaranteed, use `define-key` directly.

> **Sources:**
> - [Active Keymaps — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Active-Keymaps.html)
> - [Mastering Key Bindings in Emacs — Mastering Emacs](https://www.masteringemacs.org/article/mastering-key-bindings-emacs)

---

## The Hook System

A hook is a variable holding a list of functions to be called at a specific point. Hooks are Emacs's primary mechanism for extension without modification.

### Normal hooks

A normal hook's variable name ends in `-hook`. Functions are called with no arguments. Add with `add-hook`, remove with `remove-hook`.

```elisp
;; Add to a hook
(add-hook 'mercury-mode-hook #'flycheck-mode)

;; Add to a hook buffer-locally only (won't affect other buffers)
(add-hook 'mercury-mode-hook #'my-function nil t)  ; t = buffer-local
```

The optional third argument to `add-hook` is `DEPTH` (an integer, default 0) — lower numbers run first. Fourth argument `LOCAL` makes it buffer-local.

### Abnormal hooks

Abnormal hooks pass arguments to their functions or use return values. Their names do not end in `-hook` (convention varies). Document the calling convention explicitly in the variable's docstring.

### Standard hooks to know

| Hook | When it runs |
|---|---|
| `after-init-hook` | After `init.el` completes loading |
| `emacs-startup-hook` | After init, after command-line args processed |
| `before-save-hook` | Before a buffer is saved to its file |
| `after-save-hook` | After a buffer is saved |
| `find-file-hook` | After a file is visited |
| `kill-buffer-hook` | Before a buffer is killed |
| `window-configuration-change-hook` | When window layout changes |
| `post-command-hook` | After every command executes |
| `pre-command-hook` | Before every command executes |
| `prog-mode-hook` | When any programming major mode activates |

> **Source:** [Hooks — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Hooks.html)

---

## The Minibuffer and Completion

The minibuffer is a special buffer displayed at the bottom of the frame, used for interactive input — file names, command names, search strings. Most user-facing input in Emacs flows through it.

### `completing-read`

The core primitive for reading input with completion. Takes a prompt, a completion table (list, alist, hash table, or function), and optional predicate, require-match flag, initial input, and history variable.

```elisp
(completing-read "Choose grade: "
                 '("asm_fast.gc" "asm_fast.gc.par.stseg" "hlc.gc")
                 nil t nil 'mercury-ide/grade-history)
```

Everything that reads a symbol, function, variable, file, or buffer name ultimately calls `completing-read` or a wrapper around it (`read-buffer`, `read-command`, `read-file-name`, etc.).

### Completion tables

A completion table is what `completing-read` consults. It can be:
- A **list** of strings — simplest form
- An **alist** — pairs of (display-string . value)
- A **hash table** keyed by strings
- A **function** — called with `(string predicate action)` for programmatic completion

Completion frameworks like `vertico`, `helm`, and `ivy` work by replacing the UI that sits in front of `completing-read`, not the function itself. Your code that calls `completing-read` works with any of them.

### History variables

Each `completing-read` call should pass a dedicated history variable. Emacs stores prior inputs in that list and allows the user to cycle through them with `M-p`/`M-n`.

> **Sources:**
> - [Minibuffer Completion — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Minibuffer-Completion.html)
> - [Understanding Minibuffer Completion — Mastering Emacs](https://www.masteringemacs.org/article/understanding-minibuffer-completion)

---

## Processes

Emacs can launch and communicate with external processes. The two main models:

### Synchronous processes

Block Emacs until the process completes. Use for short-lived commands where you need the output immediately.

```elisp
;; Returns exit code; output goes to buffer or string
(call-process "mmc" nil t nil "--version")

;; Returns output as string
(shell-command-to-string "mmc --version")
```

### Asynchronous processes

Do not block Emacs. The process runs in the background; Emacs calls a **filter function** as output arrives, and a **sentinel function** when the process changes state (exits, is stopped, etc.).

```elisp
(make-process
 :name "mmc-compile"
 :buffer "*mmc-output*"
 :command (list mmc-executable "--grade" grade source-file)
 :filter  #'mercury-ide--process-filter
 :sentinel #'mercury-ide--process-sentinel)
```

**Filter function** — called with `(process output-string)` each time the process produces output. The output string may contain partial lines. Do not assume it corresponds to complete logical units.

**Sentinel function** — called with `(process event-string)` when the process changes status. `event-string` is a human-readable description: `"finished\n"`, `"exited abnormally with code 1\n"`, etc. This is where you handle process completion.

```elisp
(defun mercury-ide--process-sentinel (process event)
  (when (string-prefix-p "finished" event)
    (mercury-ide--handle-compile-success process))
  (when (string-prefix-p "exited abnormally" event)
    (mercury-ide--handle-compile-failure process)))
```

> **Sources:**
> - [Asynchronous Processes — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Asynchronous-Processes.html)
> - [Sentinels — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Sentinels.html)
> - [Output from Processes — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Output-from-Processes.html)

---

## The Display Engine

Understanding Emacs's display pipeline matters when writing anything that affects what the user sees.

### Redisplay

The redisplay engine (`xdisp.c` in the C core) redraws the screen after each command. It computes glyph matrices from buffer contents, text properties, overlays, and faces. You do not interact with it directly — you influence it by setting properties and faces, and it updates on the next redisplay cycle.

### Faces

A **face** is a named set of display attributes: foreground color, background color, font weight, slant, underline, etc. Faces are applied to text via text properties or overlays using the `face` property key.

Key functions: `defface`, `face-attribute`, `set-face-attribute`

Faces inherit from other faces. The `default` face is the base; everything inherits from it unless overridden.

### Native Compilation (Emacs 28+)

Emacs Lisp can be compiled to native code via `libgccjit`. In Emacs 28 this was optional; from Emacs 30 it is enabled by default when the library is present. Native compilation significantly speeds up execution of complex elisp — relevant for LSP clients, syntax checkers, and large configurations.

The images in this project compile Emacs with `--with-native-compilation` explicitly. Native-compiled files (`.eln`) are stored in `$EMACSDIR/.local/eln-cache/`.

### Tree-Sitter (Emacs 29+)

Tree-sitter provides incremental, error-tolerant parsing using grammar libraries. Emacs 29 introduced built-in tree-sitter support (`--with-tree-sitter` at compile time). Language grammar libraries are separate packages installed independently.

Tree-sitter enables:
- More accurate syntax highlighting than regexp-based font-lock
- Structural navigation (move by function, class, block)
- Better indentation rules
- The `-ts-mode` major mode variants (`python-ts-mode`, `c-ts-mode`, etc.)

In Doom, the `:lang` modules' `+tree-sitter` flag opts into tree-sitter-based modes where available.

> **Sources:**
> - [Font Lock Mode — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Font-Lock-Mode.html)
> - [How to Get Started with Tree-Sitter — Mastering Emacs](https://www.masteringemacs.org/article/how-to-get-started-tree-sitter)
> - [What's New in Emacs 29.1 — Mastering Emacs](https://www.masteringemacs.org/article/whats-new-in-emacs-29-1)

---

## Startup Sequence

Understanding when things load prevents configuration order bugs.

```
1. early-init.el ($EMACSDIR/early-init.el or ~/.emacs.d/early-init.el)
   ↳ Runs before GUI initializes, before package.el, before site files
   ↳ The right place for: disabling package.el, setting GC thresholds,
     preventing frame/UI flicker, disabling tool/scroll/menu bars early

2. Site startup files (/etc/emacs/site-start.el, etc.)
   ↳ System-wide configuration; runs before user init

3. package.el initialization (unless disabled in early-init.el)
   ↳ Loads installed packages from package-user-dir

4. init.el (~/.emacs.d/init.el or ~/.config/emacs/init.el)
   ↳ Your configuration; runs after packages are available
   ↳ In Doom: replaced by Doom's profile-based init system

5. after-init-hook
   ↳ Runs after init.el completes

6. emacs-startup-hook
   ↳ Runs after command-line arguments are processed
```

**`early-init.el`** was introduced in Emacs 27. Before it existed, people put performance hacks at the top of `init.el`, which ran too late to prevent some startup overhead. Move anything that must happen before the GUI initializes into `early-init.el`.

> **Sources:**
> - [Early Init File — GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Early-Init-File.html)
> - [Init File — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Init-File.html)

---

## Package Management (Vanilla Emacs)

### `package.el`

Built-in package manager. Installs from ELPA, MELPA, and other archives configured in `package-archives`. Packages are downloaded as `.tar` archives and installed into `package-user-dir`.

```elisp
;; In init.el
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
```

### `use-package`

A macro for declaring and configuring packages. Built into Emacs since version 29; available as a package for earlier versions.

```elisp
(use-package flycheck
  :hook (prog-mode . flycheck-mode)
  :config
  (setq flycheck-display-errors-delay 0.5))
```

Key keywords: `:init` (runs before load), `:config` (runs after load), `:hook`, `:bind`, `:after`, `:defer`, `:ensure` (install if absent), `:disabled`.

In Doom, `use-package!` wraps this with Doom's module-awareness. In vanilla Emacs, use `use-package` directly.

> **Sources:**
> - [use-package User Manual — gnu.org](https://www.gnu.org/software/emacs/manual/html_mono/use-package.html)

---

## The Built-In Help System

Emacs's help system is the single most important tool for navigating both Emacs and your own configuration. Every function, variable, face, and keymap is self-describing.

### Core help commands (`C-h` prefix)

| Binding | Command | What it shows |
|---|---|---|
| `C-h f` | `describe-function` | Docstring, source location, any keybindings |
| `C-h v` | `describe-variable` | Docstring, current value, source location |
| `C-h k` | `describe-key` | Which command a key sequence invokes |
| `C-h K` | `describe-keymap` | All bindings in a keymap |
| `C-h m` | `describe-mode` | Current major and minor modes, their bindings |
| `C-h o` | `describe-symbol` | Function, variable, or face — any symbol |
| `C-h a` | `apropos-command` | Find commands matching a string or regexp |
| `C-h d` | `apropos-documentation` | Search docstrings for a string |
| `C-h l` | `view-lossage` | Last 300 keystrokes |
| `C-h e` | `view-echo-area-messages` | Recent messages buffer |
| `C-h i` | `info` | The full Info documentation tree |

### Navigation in help buffers

- Click or press `RET` on a hyperlinked symbol to jump to its documentation
- Press `l` to go back (like a browser back button)
- Help buffers show a link to the source file — click it to jump directly to the definition

### `helpful` — better help buffers

The [`helpful`](https://github.com/Wilfred/helpful) package replaces the standard `*Help*` buffer with richer output: inline source code, usage examples, value history for variables, and links to all callers. Doom's `:ui doom` module installs it by default. If installed, Doom remaps `C-h f`, `C-h v`, and `C-h k` to the `helpful-*` variants automatically. The information is the same as the built-in system; the presentation is substantially clearer.

### `*Messages*` buffer

All messages Emacs prints to the echo area are logged in `*Messages*`. When something goes wrong silently, check here first. `M-x view-echo-area-messages` or `C-h e`.

### `*Backtrace*` buffer

When Emacs signals an unhandled error, a backtrace buffer appears. It shows the full call stack at the point of the error. Learn to read it — it is the primary debugging tool.

Enable `toggle-debug-on-error` (`M-x`) to make Emacs open a backtrace on any error instead of just printing a message. Essential during development.

> **Sources:**
> - [Help Summary — GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html)
> - [Help Functions — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Help-Functions.html)

---

## Finding Things in Emacs

A structured approach to locating information when you don't know where something is:

| Question | Tool |
|---|---|
| What does this function do? | `C-h f function-name` |
| What does this variable do / what is its value? | `C-h v variable-name` |
| What key runs this command? | `C-h f` then look at "It is bound to" |
| What does this key do? | `C-h k` then press the key |
| What are all the bindings in this mode? | `C-h m` |
| Where is this function defined? | `C-h f` then click the source link; or `M-.` (xref) |
| I know part of a function name | `C-h a partial-name` |
| I know what something does but not its name | `C-h d description-words` |
| Why is this key not doing what I expect? | `C-h k` to see what's actually bound; check `C-h m` for overriding minor modes |
| What changed recently? | `M-x view-echo-area-messages`; check `*Messages*` |
| Something errored silently | `M-x toggle-debug-on-error` then reproduce |
| What package installed this? | `C-h f` → source link → identifies the file |

---

## Key Reference Manual Sections

The GNU Emacs Lisp Reference Manual is the authoritative source. These are the sections most relevant to this project, linked directly:

### Data model
- [Buffer Basics](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Basics.html)
- [Buffer Internals](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-Internals.html)
- [Windows](https://www.gnu.org/software/emacs/manual/html_node/elisp/Windows.html)
- [Frames](https://www.gnu.org/software/emacs/manual/html_node/elisp/Frames.html)
- [Markers](https://www.gnu.org/software/emacs/manual/html_node/elisp/Markers.html)
- [Point](https://www.gnu.org/software/emacs/manual/html_node/elisp/Point.html)

### Text annotation
- [Text Properties](https://www.gnu.org/software/emacs/manual/html_node/elisp/Text-Properties.html)
- [Overlays](https://www.gnu.org/software/emacs/manual/html_node/elisp/Overlays.html)
- [Overlay Properties](https://www.gnu.org/software/emacs/manual/html_node/elisp/Overlay-Properties.html)
- [Font Lock Mode](https://www.gnu.org/software/emacs/manual/html_node/elisp/Font-Lock-Mode.html)

### Modes
- [Major Modes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Major-Modes.html)
- [Major Mode Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Major-Mode-Conventions.html)
- [Minor Mode Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Minor-Mode-Conventions.html)
- [Defining Minor Modes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Minor-Modes.html)

### Keymaps
- [Active Keymaps](https://www.gnu.org/software/emacs/manual/html_node/elisp/Active-Keymaps.html)
- [Controlling Active Maps](https://www.gnu.org/software/emacs/manual/html_node/elisp/Controlling-Active-Maps.html)
- [Standard Keymaps](https://www.gnu.org/software/emacs/manual/html_node/elisp/Standard-Keymaps.html)

### Hooks
- [Hooks](https://www.gnu.org/software/emacs/manual/html_node/elisp/Hooks.html)
- [Standard Hooks](https://www.gnu.org/software/emacs/manual/html_node/elisp/Standard-Hooks.html)

### Minibuffer and completion
- [Minibuffer Completion](https://www.gnu.org/software/emacs/manual/html_node/elisp/Minibuffer-Completion.html)
- [Minibuffer History](https://www.gnu.org/software/emacs/manual/html_node/elisp/Minibuffer-History.html)

### Processes
- [Asynchronous Processes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Asynchronous-Processes.html)
- [Sentinels](https://www.gnu.org/software/emacs/manual/html_node/elisp/Sentinels.html)
- [Output from Processes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Output-from-Processes.html)

### Startup and configuration
- [Early Init File — GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Early-Init-File.html)
- [Init File — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Init-File.html)

### Help
- [Help Summary — GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html)
- [Help Functions — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Help-Functions.html)

---

## Master Reference List

### Official GNU documentation
- [GNU Emacs Manual](https://www.gnu.org/software/emacs/manual/emacs.html)
- [GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/elisp.html)
- [An Introduction to Programming in Emacs Lisp](https://www.gnu.org/software/emacs/manual/eintr.html)
- [use-package User Manual](https://www.gnu.org/software/emacs/manual/html_mono/use-package.html)
- [New in Emacs 30 — GNU Emacs FAQ](https://www.gnu.org/software/emacs/manual/html_node/efaq/New-in-Emacs-30.html)

### Secondary references
- [Mastering Emacs — masteringemacs.org](https://www.masteringemacs.org/)
- [Mastering Key Bindings in Emacs — Mastering Emacs](https://www.masteringemacs.org/article/mastering-key-bindings-emacs)
- [Understanding Minibuffer Completion — Mastering Emacs](https://www.masteringemacs.org/article/understanding-minibuffer-completion)
- [How to Get Started with Tree-Sitter — Mastering Emacs](https://www.masteringemacs.org/article/how-to-get-started-tree-sitter)
- [What's New in Emacs 29.1 — Mastering Emacs](https://www.masteringemacs.org/article/whats-new-in-emacs-29-1)
- [How to Make an Emacs Minor Mode — null program](https://nullprogram.com/blog/2013/02/06/)
- [EmacsWiki — Emacs Overlays](https://www.emacswiki.org/emacs/EmacsOverlays)
- [helpful — Wilfred/helpful (GitHub)](https://github.com/Wilfred/helpful)
