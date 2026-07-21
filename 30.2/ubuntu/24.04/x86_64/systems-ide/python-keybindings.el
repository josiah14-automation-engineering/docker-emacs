;;; python-keybindings.el --- Python mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in python-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck -- python-ruff checker,
;;                                        built into flycheck, no extra
;;                                        package needed)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;   M-r         evaluate buffer in REPL (+eval/buffer, :tools eval;
;;                                        Doom's own python module wires
;;                                        this to a real python3 subprocess)
;;
;; Doom's own :lang python module wires LSP auto-attach (pyright, since
;; this image only installs pyright -- no ty/basedpyright/jedi to create
;; ambiguity) and the REPL automatically. Format-on-save runs ruff
;; (config.el overrides apheleia's own default of black for python-mode).
;;
;; pyright does not implement LSP-level document formatting (it's a
;; type-checker/language-intelligence server only, not a formatter --
;; this is exactly why apheleia needs its own independent python-mode
;; formatter mapping regardless of which LSP server is used) -- so the
;; on-demand format binding below calls apheleia directly rather than
;; `lsp-format-buffer', unlike c-keybindings.el/lua-keybindings.el, where
;; the LSP server itself (clangd/lua-language-server) does implement
;; formatting. Worth reconciling later: those two files' on-demand format
;; bindings and their own on-save formatters (clang-format, stylua) happen
;; to be the same underlying tool, so this inconsistency hasn't caused a
;; visible problem yet, but `apheleia-format-buffer' is the more correct,
;; universally-applicable choice and is what this file and
;; ruby-keybindings.el/javascript-keybindings.el use going forward.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer, i.e. ruff -- on-demand,
;;                        in addition to format-on-save)

;;; Code:

(map! :map python-mode-map
      :localleader
      :desc "Format buffer" "f" #'apheleia-format-buffer)

(provide 'python-keybindings)
;;; python-keybindings.el ends here
