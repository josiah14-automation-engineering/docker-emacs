;;; all-lisps-config.el --- Cross-lisps dev-tooling plumbing and config -*- lexical-binding: t; -*-

;;; Commentary:

;; Editing-experience settings meant to apply across every Lisp dialect
;; this setup touches (Emacs Lisp today; Guile Scheme, and possibly
;; SBCL/Racket/scsh/rash, planned) -- as opposed to config.el's own
;; per-language files, which are scoped to one specific mode/toolchain.
;;
;; No `after!' wrapper needed here: unlike lsp-mode/apheleia-style
;; config, nothing below depends on a package being loaded first --
;; `put' on a symbol works unconditionally, at any point during startup.

;;; Code:

;; Doom's `map!' macro has no `(declare (indent N))' of its own, and
;; `:prefix' (its nested-prefix DSL keyword) isn't a real special form
;; either -- so `calculate-lisp-indent' falls back to generic "align
;; under the first argument" indentation for any `(:prefix "x" ...)'
;; form, which cascades deeper with each level of nesting.
;;
;; `1' here (not `'defun') means "one positional argument (the prefix
;; string) follows the head, everything after is body" -- this gives
;; the same clean, non-cascading fixed step per nesting level `'defun'
;; would, but *also* lines up a form's own body up with its one
;; positional argument, e.g. in `(:prefix "w" :desc "..." "S" #'foo)'
;; wrapped across lines, `:desc' lands in the same column as `:prefix'
;; itself. `'defun' gives the same nesting step but leaves `:desc' one
;; column off from `:prefix' -- confirmed by testing both live.
;;
;; This is process-wide, not scoped to emacs-lisp-mode: `put' sets a
;; property directly on the `:prefix' symbol, and every Lisp-family
;; mode sharing the built-in `calculate-lisp-indent' machinery --
;; confirmed live against both `lisp-mode' and `scheme-mode', not just
;; `emacs-lisp-mode' -- consults that same property. Accepted
;; deliberately: `:prefix' as a list head is a distinctly Doom/Emacs-
;; Lisp DSL pattern, not idiomatic in Common Lisp/Scheme/Racket, so the
;; collision risk for other Lisp dialects is low.
;;
;; If a specific project ever wants different Lisp indent behavior than
;; this global default, the right lever is *not* another `put' on this
;; same property (still the same global symbol slot, so it would just
;; as easily stomp on other buffers). `calculate-lisp-indent' actually
;; reads the property through a genuine, ordinary variable -- also
;; (confusingly) named `lisp-indent-function', whose default value
;; happens to be a function of the same name that does the property
;; lookup. That variable is a normal defcustom, not a symbol property,
;; so it's buffer-local-able the same way `lsp-auto-guess-root' is: a
;; project's own `.dir-locals.el' can rebind *that* to something else
;; (nil, `common-lisp-indent-function', a fully custom function) for
;; its own buffers, with zero interference with any other project's
;; open buffers -- genuine per-project formatting configuration, using
;; Emacs's own native mechanism, no advice needed.
(put ':prefix 'lisp-indent-function 1)

(provide 'all-lisps-config)
;;; all-lisps-config.el ends here
