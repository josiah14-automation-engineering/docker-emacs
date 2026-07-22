;;; asm-config.el --- Assembly (asm-mode) configuration -*- lexical-binding: t; -*-

;;; Code:

;; asm-mode ships built into Emacs core, with .s/.S/.asm already in the
;; default auto-mode-alist (confirmed live: `emacs -Q --batch' against
;; this exact Emacs build maps all three to asm-mode out of the box) --
;; no separate package, no auto-mode-alist wiring needed for the mode
;; itself, unlike fish-mode.

;; No Doom :lang module exists for assembly (confirmed against the pinned
;; Doom commit's modules/lang/ tree -- doomemacs has never shipped one),
;; so nothing calls `lsp!' automatically when a .s/.asm buffer opens.
;; Mirror Doom's own convention directly, same shape as nu-config.el/
;; fish-config.el.
(add-hook 'asm-mode-local-vars-hook #'lsp! 'append)

;; lsp-mode already ships a built-in asm-lsp client (clients/lsp-asm.el),
;; but like lsp-nushell before it (nu-config.el), it only auto-loads once
;; some buffer's major-mode already matches an already-loaded client's
;; activation function -- nothing else registers it, so force the
;; require explicitly once lsp-mode itself is loading. No manual
;; lsp-register-client/lsp-language-id-configuration entry needed here,
;; unlike fish-config.el: lsp-asm.el registers asm-mode directly (see
;; `lsp-asm-active-modes'), and diagnostics come from asm-lsp itself
;; invoking gcc/clang (both already installed for C/C++), not flycheck.
(after! lsp-mode
  (require 'lsp-asm))

(provide 'asm-config)
;;; asm-config.el ends here
