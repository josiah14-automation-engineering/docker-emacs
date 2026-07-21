;;; typescript-keybindings.el --- TypeScript mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in typescript-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck -- javascript-oxlint
;;                                        checker, built into flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; `.ts' files get their own major mode (typescript-mode, a distinct
;; keymap from js-mode-map) but the same ts-ls (typescript-language-server)
;; backend as js-mode -- see javascript-keybindings.el's Commentary for why
;; oxlint/typescript@6.0.3/etc were chosen; all of that applies here
;; unchanged. Format-on-save uses apheleia's existing default mapping for
;; typescript-mode (prettier-typescript), unchanged -- no override needed
;; here either.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer, i.e. prettier --
;;                        on-demand, in addition to format-on-save; see
;;                        python-keybindings.el's Commentary for why this
;;                        is apheleia directly rather than
;;                        `lsp-format-buffer'). Doom's own :lang javascript
;;                        module never wires this for typescript-mode-map
;;                        (only js-mode-map) -- confirmed by opening a .ts
;;                        file and checking `SPC m f' resolved to nil
;;                        before this file existed.

;;; Code:

(map! :map typescript-mode-map
      :localleader
      :desc "Format buffer" "f" #'apheleia-format-buffer)

(provide 'typescript-keybindings)
;;; typescript-keybindings.el ends here
