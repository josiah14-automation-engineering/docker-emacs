;;; c-keybindings.el --- C/C++ mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in c-mode/c++-mode/objc-mode buffers
;; (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; Doom's own :lang cc module wires all of the above automatically, plus
;; ccls-specific navigation/caller/callee bindings under the localleader --
;; those stay inert here, since this image installs clangd only (ccls has
;; no apt package and no prebuilt release binaries; building it from source
;; against a matching libclang would be real added build fragility for a
;; server this image deliberately doesn't use). clangd is prioritized over
;; ccls by Doom's own module regardless, so nothing further was needed to
;; make that the effective default.
;;
;; LOCAL-LEADER — this file's own bindings (SPC m ...):
;;   f   format buffer   (lsp-format-buffer, backed by clangd -- no separate
;;                        clang-format binary needed)

;;; Code:

(map! :map (c-mode-map c++-mode-map objc-mode-map)
      :localleader
      :desc "Format buffer" "f" #'lsp-format-buffer)

(provide 'c-keybindings)
;;; c-keybindings.el ends here
