;;; lua-keybindings.el --- Lua mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in lua-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;   M-r         evaluate buffer in REPL (+eval/buffer, :tools eval)
;;
;; Doom's own :lang lua module wires all of the above automatically once
;; `lua-language-server' is on PATH/configured (see config.el's
;; lsp-clients-lua-language-server-bin): local-vars-hook attaches LSP,
;; `set-repl-handler!' wires the buffer/region eval bindings to a real
;; `lua'/`luajit' subprocess, and format-on-save runs stylua via Doom's
;; :editor format module -- none of that needed reimplementing here, only
;; installing the two binaries themselves (Dockerfile).
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (lsp-format-buffer, backed by lua-language-server
;;                        for on-demand formatting in addition to
;;                        format-on-save; stylua itself is Doom's actual
;;                        formatter for the on-save path)

;;; Code:

(map! :map lua-mode-map
      :localleader
      :desc "Format buffer" "f" #'lsp-format-buffer)

(provide 'lua-keybindings)
;;; lua-keybindings.el ends here
