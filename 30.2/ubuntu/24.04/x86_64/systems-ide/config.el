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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load language configs and keybindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(load! "go-config")
(load! "shell-config")
(load! "bats-config")
(load! "nu-config")
(load! "global-keybindings")
(load! "sh-keybindings")
(load! "go-keybindings")
(load! "nix-keybindings")
(load! "bats-keybindings")
(load! "nu-keybindings")
(load! "c-keybindings")
(load! "cmake-keybindings")
