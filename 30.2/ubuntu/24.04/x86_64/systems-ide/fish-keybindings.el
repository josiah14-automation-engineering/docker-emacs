;;; fish-keybindings.el --- Fish mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in fish-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck, via fish-lsp's own
;;                                        diagnostics)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; fish-config.el wires fish-lsp (ndonfris/fish-lsp) onto fish-mode by
;; hand -- lsp-mode ships no built-in client for it, unlike Nushell/
;; Assembly. Format-on-save runs fish's own `fish_indent' -- already
;; apheleia's own default for fish-mode, no override needed.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer, i.e. fish_indent --
;;                        on-demand, in addition to format-on-save; see
;;                        python-keybindings.el's Commentary for why this
;;                        is apheleia directly rather than
;;                        `lsp-format-buffer')

;;; Code:

(map! :map fish-mode-map
      :localleader
      :desc "Format buffer" "f" #'apheleia-format-buffer)

(provide 'fish-keybindings)
;;; fish-keybindings.el ends here
