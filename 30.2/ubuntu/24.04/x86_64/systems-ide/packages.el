;;; packages.el -*- lexical-binding: t; -*-

;; TOML — no Doom module exists; add mode and LSP wiring manually.
;; toml-ts-mode ships with Emacs 29+; toml-mode is the fallback for older Emacs.
(package! toml-mode)

;; Fish shell syntax highlighting — not covered by :lang sh.
(package! fish-mode)

;; Geiser backends — :lang (scheme +guile) installs geiser core; this pins the
;; Guile-specific backend explicitly so it's always present.
(package! geiser-guile)
