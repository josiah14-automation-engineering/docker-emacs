;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq user-full-name <full-name>
      user-mail-address <email-address>)

(setq doom-theme 'doom-solarized-dark)

(setq org-directory "~/org/")

(setq display-line-numbers-type 'relative)

(use-package! company
  :config
  (global-company-mode))

;; Make flycheck-elisp aware of Doom's macro environment so that Doom DSL
;; constructs like `map!' expand correctly during byte-compile checks.
;;
;; The problem: flycheck's emacs-lisp checker byte-compiles each file in a
;; subprocess — a fresh Emacs instance that starts without Doom loaded.  When
;; it encounters `(map! ... (:prefix ("p" . "profile") ...))' it tries to
;; expand the macro, but `map!' is not defined, so it treats it as a plain
;; function call and calls `proper-list-p' on the ("p" . "profile") cons cell,
;; which fails because a cons cell is not a proper list.  The error is a false
;; positive; the code is valid Doom DSL.
;;
;; `after!' is a Doom macro that defers the body until the named feature
;; (here `flycheck') has been loaded.  This avoids errors at startup if
;; flycheck loads late, and is the idiomatic Doom alternative to
;; `with-eval-after-load'.
;;
;; `setq-hook!' is a Doom macro that sets variables buffer-locally whenever a
;; given hook fires — here `emacs-lisp-mode-hook', which runs every time Emacs
;; opens an Emacs Lisp file.  Buffer-local means each elisp buffer gets its
;; own copy of these values, leaving the global defaults untouched for any
;; non-elisp buffers that flycheck checks.
;;
;; `flycheck-emacs-lisp-load-path' controls which directories the subprocess
;; searches when resolving `require' calls.  The symbol `inherit' (not the
;; string "inherit") tells flycheck to forward the running Emacs's full
;; `load-path' to the subprocess.  Because this image runs Doom, `load-path'
;; already includes ~/.config/emacs/lisp/, so the subprocess can locate
;; doom-lib.el and doom-keybinds.el.
;;
;; `flycheck-emacs-lisp-check-form' is the elisp expression — stored as a
;; string — that flycheck passes to the subprocess to perform the actual check.
;; Its default value is roughly:
;;
;;   "(let ((jka-compr-inhibit t)) (byte-compile-file \"%s\"))"
;;
;; where %s is replaced at check time with the path of a temp copy of the file
;; under inspection.  `concat' prepends two `require' calls to that string:
;; `doom-lib' (Doom's core utility library, a dependency of doom-keybinds) and
;; `doom-keybinds' (which defines `map!').  The subprocess finds those files
;; via the inherited load-path.  The %s substitution in the original form is
;; unaffected because `concat' joins strings without interpreting %s.
(after! flycheck
  (setq-hook! 'emacs-lisp-mode-hook
    flycheck-emacs-lisp-load-path 'inherit
    flycheck-emacs-lisp-check-form (concat "(require 'doom-lib)"
                                           "(require 'doom-keybinds)"
                                           flycheck-emacs-lisp-check-form)))

;; Wrap completion candidates — bottom candidate cycles back to top and vice versa.
(setq vertico-cycle t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LSP adjustments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(after! lsp-mode
  (setq lsp-modeline-code-action-fallback-icon
        (nerd-icons-codicon "nf-cod-lightbulb"))
  ;; Without this, opening a file lsp-mode hasn't seen before (e.g. a lone
  ;; .h opened before its .c sibling) blocks on a synchronous "import
  ;; project?" prompt in the minibuffer. Because Emacs is single-threaded,
  ;; that prompt also wedges every other emacsclient connection until it's
  ;; answered -- fatal for the daemon-driven smoketest flow. Auto-accepting
  ;; the guessed root avoids the prompt entirely.
  (setq lsp-auto-guess-root t))

;; Doom prepends `project-projectile' ahead of project.el's own VC backend
;; in `project-find-functions', so it's Projectile's root-finding, not
;; project.el's, that governs LSP workspace-root detection (via
;; `lsp-auto-guess-root' above) and everything else that calls
;; `project-current'/`projectile-project-root'.
;; `projectile-project-root-files-bottom-up' -- the marker list that
;; correctly handles a project nested inside a bigger VCS tree, by
;; returning the *closest* match rather than the outermost -- only has
;; VCS markers by default, missing every one of this project's own "full
;; support" tier build-system files. Any of this repo's own flight-test
;; fixtures (nested inside this repo's own git tree, by construction)
;; resolved to the outer repo root instead of their own project root:
;; rust-analyzer/gopls/clangd all initialized against the wrong
;; workspace, silently unable to find Cargo.toml/go.mod/CMakeLists.txt.
;; Same root cause already fixed for the debugger side of Rust/Go/C (see
;; dape-config.el's +dape-resolve-cwd/+dape-go-root and DECISIONLOG.md)
;; -- this is the LSP-side half of the same bug, caught later because
;; dape's debugger configs already bypass project/projectile entirely,
;; while LSP root-guessing has no such bypass and goes straight through
;; this list. Verified live against all three fixtures after adding
;; these: workspace root correctly resolves to the nested project
;; directory, not the repo root.
(after! projectile
  (dolist (marker '("Cargo.toml" "go.mod" "CMakeLists.txt"))
    (add-to-list 'projectile-project-root-files-bottom-up marker)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dir-locals trust
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; `flight-tests/guile/.dir-locals.el' adds its own directory to
;; `geiser-guile-load-path' via an `eval' clause -- the only way to
;; reference `default-directory' dynamically rather than hardcoding an
;; absolute path that would break on a different checkout location.
;; Emacs prompts to trust unfamiliar `eval' dir-locals by default (a real
;; safety feature, not something to disable wholesale via
;; `enable-local-eval' -- that would trust eval forms in every project
;; this Emacs ever opens, not just this repo's own fixture). Whitelisting
;; this one exact form instead keeps the trust boundary scoped to
;; something this repo's own smoketest actually needs, without touching
;; the global setting.
(add-to-list 'safe-local-eval-forms
             '(add-to-list 'geiser-guile-load-path default-directory))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load language configs and keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(load! "all-lisps-config")
(load! "go-config")
(load! "shell-config")
(load! "bats-config")
(load! "nu-config")
(load! "dape-config")
(load! "lua-config")
(load! "python-config")
(load! "ruby-config")
(load! "fish-config")
(load! "asm-config")
(load! "toml-config")
(load! "global-keybindings")
(load! "polyglot-keybindings")
(load! "sh-keybindings")
(load! "go-keybindings")
(load! "nix-keybindings")
(load! "bats-keybindings")
(load! "nu-keybindings")
(load! "c-keybindings")
(load! "cmake-keybindings")
(load! "docker-keybindings")
(load! "lua-keybindings")
(load! "python-keybindings")
(load! "ruby-keybindings")
(load! "javascript-keybindings")
(load! "typescript-keybindings")
(load! "rust-keybindings")
(load! "guile-keybindings")
(load! "fish-keybindings")
