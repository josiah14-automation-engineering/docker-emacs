;;; nu-config.el --- Nushell mode configuration -*- lexical-binding: t; -*-

;;; Code:

;; nushell-ts-mode's own file registers it in auto-mode-alist/interpreter-
;; mode-alist inside a top-level (when (treesit-ready-p 'nu) ...) form, not
;; behind an autoload cookie -- so nothing associates .nu files with it until
;; the whole file is actually required at least once. Nothing else triggers
;; that on its own, so force it eagerly here, the same fix shape bats-
;; config.el needed for sh-script's auto-mode-alist race. The 'nu tree-
;; sitter grammar is compiled at image build time (see Dockerfile), so
;; treesit-ready-p is already true by the time this runs.
(require 'nushell-ts-mode)

;; nushell-ts-mode derives from plain prog-mode, not from any mode Doom's
;; :lang modules already wire up for LSP (unlike sh-mode/go-mode/nix-mode,
;; whose own :lang module hooks `lsp!' onto their <mode>-local-vars-hook).
;; With no Doom :lang module for nushell, nothing would call `lsp!'
;; automatically when a .nu buffer opens. Mirror Doom's own convention
;; directly instead.
(add-hook 'nushell-ts-mode-local-vars-hook #'lsp! 'append)

;; lsp-mode's nushell-ls client lives in the separate clients/lsp-nushell.el,
;; which -- like clients/lsp-bash.el before it (see bats-config.el) -- only
;; auto-loads once some buffer's major-mode already matches one of an
;; already-loaded client's activation function. Nothing else registers
;; nushell-ls, so force the require explicitly once lsp-mode itself is
;; loading (deferred, not eager, so lsp-mode isn't pulled in at Doom
;; startup just because this file loaded). lsp-mode's default
;; lsp-language-id-configuration already maps nushell-ts-mode -> "nushell"
;; out of the box, same as plain nushell-mode, so nothing else needs
;; updating here beyond requiring the client file.
(after! lsp-mode
  (require 'lsp-nushell))

(provide 'nu-config)
;;; nu-config.el ends here
