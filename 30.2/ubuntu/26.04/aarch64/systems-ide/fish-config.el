;;; fish-config.el --- Fish shell (fish-mode) configuration -*- lexical-binding: t; -*-

;;; Code:

;; fish-mode's own file registers .fish, fish_funced.*, and the `fish'
;; interpreter shebang line via `;;;###autoload' cookies (confirmed
;; directly from source) -- no manual auto-mode-alist wiring needed for
;; the mode itself, unlike nushell-ts-mode's build-time race (nu-config.el).

;; No Doom :lang module exists for fish (confirmed against the pinned Doom
;; commit's modules/lang/ tree -- doomemacs has never shipped one), so
;; nothing calls `lsp!' automatically when a .fish buffer opens. Mirror
;; Doom's own convention directly, same shape as nu-config.el/asm-config.el.
(add-hook 'fish-mode-local-vars-hook #'lsp! 'append)

;; Unlike Nushell/Assembly, lsp-mode ships no built-in fish-lsp client at
;; all (confirmed -- no clients/lsp-fish.el exists in lsp-mode) -- fish-lsp
;; (ndonfris/fish-lsp, npm) needs to be registered by hand, the same shape
;; TOML's own plan calls for. `lsp-stdio-connection' takes the literal
;; argv: fish-lsp's own docs invoke it as `fish-lsp start', not a bare
;; `fish-lsp' with no subcommand.
(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration '(fish-mode . "fish"))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("fish-lsp" "start"))
                    :major-modes '(fish-mode)
                    :server-id 'fish-lsp)))

;; apheleia already defaults fish-mode to its own `fish-indent' formatter
;; (`fish_indent', confirmed directly from apheleia-formatters.el) -- no
;; override needed here, unlike ruby-config.el/python-config.el overriding
;; apheleia's defaults for their own modes.

(provide 'fish-config)
;;; fish-config.el ends here
