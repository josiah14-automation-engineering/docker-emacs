;;; packages.el -*- lexical-binding: t; -*-

(package! realgud)              ;; for zsh debugging
(package! nushell-ts-mode)      ; Tree-sitter mode for highlighting, indentation, completion.
(package! flycheck-golangci-lint) ;; inline golangci-lint diagnostics in go-mode
(package! bats-mode)            ;; major mode for editing/running .bats test files
(package! fish-mode)            ;; major mode for .fish scripts (wwwjfy/emacs-fish)
(package! toml-mode)            ;; major mode for .toml files (dryman/toml-mode.el)

;; Gerbil has no Doom :lang flag (it's a dialect/toolchain layered on
;; Gambit, not a Geiser backend) and etc/gerbil-mode.el isn't a
;; standalone MELPA package -- it's one file inside the mighty-gerbils/
;; gerbil monorepo, so :files pulls just that path out. Pinned to the
;; exact commit the v0.18.2 tag resolves to (confirmed live via `gh api
;; repos/mighty-gerbils/gerbil/commits/v0.18.2`), matching
;; josiah14/gerbil's own bundled binary (confirmed live: that image's
;; `gerbil -v` reports "Gerbil v0.18.2") -- this is the commit where
;; gerbil-mode.el was rewritten to a proper `define-derived-mode', so
;; the mode's own behavior stays consistent with the actual installed
;; toolchain rather than drifting from it.
(package! gerbil-mode
  :recipe (:host github :repo "mighty-gerbils/gerbil"
           :files ("etc/gerbil-mode.el"))
  :pin "07c8481588a8b07dbf05832687817cd398902ac0")
