;;; toml-config.el -*- lexical-binding: t; -*-

;; No Doom `:lang' module exists for TOML -- toml-mode (dryman/toml-mode.el,
;; installed via packages.el) self-registers `auto-mode-alist' for `.toml'
;; on its own, but LSP wiring has to be done by hand here since there's no
;; lang/toml module to provide it, unlike every `+lsp'-flagged language in
;; init.el.
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(toml-mode . "toml"))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection "taplo lsp stdio")
                     :major-modes '(toml-mode)
                     :server-id 'taplo)))

(add-hook 'toml-mode-hook #'lsp!)
