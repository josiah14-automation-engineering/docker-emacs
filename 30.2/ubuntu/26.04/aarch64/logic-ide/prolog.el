;;; prolog.el -*- lexical-binding: t; -*-

;; sweeprolog embeds SWI-Prolog directly into Emacs as a dynamic module,
;; giving real diagnostics from the actual SWI-Prolog reader/compiler (not a
;; shelled-out linter), plus xref, completion-at-point, Eldoc, and
;; structural editing. `sweeprolog-mode' is its own major mode (derived from
;; `prog-mode', not a minor mode layered on `prolog-mode'), and it enables
;; flymake itself internally whenever `sweeprolog-enable-flymake' is
;; non-nil (the default) -- no separate flymake hook needed or available.
;;
;; `:mode' both registers the autoload and the `auto-mode-alist' entry,
;; overriding `perl-mode''s default claim on `.pl' -- fine here since this
;; image has no Perl tooling and `.pl'/`.pro'/`.plt' are the conventional
;; SWI-Prolog source/unit-test extensions.
(use-package! sweeprolog
  :mode ("\\.p\\(?:l\\|ro\\|lt\\)\\'" . sweeprolog-mode)
  :hook (sweeprolog-mode . sweeprolog-forward-hole-on-tab-mode))
