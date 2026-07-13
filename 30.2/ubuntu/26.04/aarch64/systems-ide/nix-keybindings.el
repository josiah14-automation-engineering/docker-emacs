;;; nix-keybindings.el -*- lexical-binding: t; -*-

;; Doom nix module default SPC m bindings (unchanged):
;;
;;   s   nix-shell             enter a nix-shell environment
;;   b   nix-build             run nix-build
;;   u   nix-unpack            unpack a source derivation
;;   o   +nix/lookup-option    browse NixOS options with inline docs
;;
;; With +lsp, nil registers standard Doom LSP slots:
;;   g   goto group (definition, references, type-def, implementations)
;;   h   help group (hover docs, describe symbol)
;;   a   code actions
;;   r   rename (LSP rename; shadows nix module's nix-repl-show — see SPC m l r)

;; Overrides: f and p are swapped back to the cross-IDE convention (f = format).
;; The nix module binds them the other way around. Must be wrapped in
;; after! nix-mode -- the nix module's own f/p defaults are set lazily inside
;; its :config block, which runs on first .nix file visit and silently
;; overwrites a plain map! written earlier in load order (same race as
;; go-keybindings.el).
(after! nix-mode
  (map! :localleader
        :map nix-mode-map
        "f" #'nix-format-buffer
        "p" #'nix-update-fetch
        (:prefix ("l" . "flake")
         "c" (cmd! (compile "nix flake check"))
         "u" (cmd! (compile "nix flake update"))
         "d" (cmd! (async-shell-command "nix develop"))
         "r" #'nix-repl-show)))

(provide 'nix-keybindings)
