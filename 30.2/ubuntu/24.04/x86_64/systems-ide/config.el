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
  (setq lsp-auto-guess-root t)
  ;; lsp-mode's own default install path for lua-language-server is a
  ;; `.cache/lsp/` directory under $EMACSDIR that has shifted convention
  ;; across lsp-mode versions -- pointed explicitly at this image's fixed
  ;; install location instead of betting on hitting the current default
  ;; correctly. The `main.lua` sibling and `locale/` directory (main.lua's
  ;; expected relative to the install-dir root, not the binary) come along
  ;; for free since the whole release archive was extracted as a tree,
  ;; not just this one binary copied out.
  (setq lsp-clients-lua-language-server-bin
        (expand-file-name "~/.local/lib/lua-language-server/bin/lua-language-server"))
  ;; Both `ruby-lsp` and `rubocop --lsp` register as LSP clients for
  ;; ruby-mode (rubocop-ls, rubocop's own built-in LSP mode); rubocop-ls's
  ;; priority (-1) beats ruby-lsp-ls's (-2), so lsp-mode picked rubocop-ls
  ;; alone -- and rubocop's LSP server only implements diagnostics/
  ;; formatting, not completion, silently leaving ruby-mode buffers with
  ;; lsp-mode reporting "on" but zero completion candidates ever offered.
  ;; Disabled so ruby-lsp-ls (the completion-capable server) attaches
  ;; instead; rubocop still runs diagnostics via flycheck's own built-in
  ;; ruby-rubocop checker (see ruby-keybindings.el), so nothing is lost.
  (add-to-list 'lsp-disabled-clients 'rubocop-ls)
  ;; ruby-lsp's own internal bootstrap hard-requires the `bundle`
  ;; executable and a specific pinned gem set (see the Dockerfile's
  ;; BUNDLE_GEMFILE comment for the full story -- this isn't optional the
  ;; way it looks from lsp-ruby-lsp.el's docstring). `t` here makes
  ;; lsp-mode launch `bundle exec ruby-lsp` against that pre-built,
  ;; offline, pinned bundle rather than a bare `ruby-lsp`, which -- with
  ;; the BUNDLE_GEMFILE env var also set globally in the Dockerfile --
  ;; would otherwise skip ruby-lsp's own bootstrap entirely and load
  ;; whatever gem versions happen to be active, unpinned.
  (setq lsp-ruby-lsp-use-bundler t))

;; apheleia (Doom's :editor format backend) defaults python-mode to black
;; and ruby-mode to prettier-ruby (an npm-based prettier plugin) -- both
;; overridden so each language uses just one already-installed tool for
;; both linting and formatting, rather than pulling in a second, unrelated
;; toolchain (black needs its own pip/pipx install; prettier-ruby needs a
;; Node-based plugin) for formatting alone.
(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff)
  (setf (alist-get 'ruby-mode apheleia-mode-alist) 'rubocop))

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
(load! "lua-keybindings")
(load! "python-keybindings")
(load! "ruby-keybindings")
(load! "javascript-keybindings")
(load! "typescript-keybindings")
(load! "rust-keybindings")
(load! "nu-keybindings")
(load! "c-keybindings")
(load! "cmake-keybindings")
(load! "docker-keybindings")
