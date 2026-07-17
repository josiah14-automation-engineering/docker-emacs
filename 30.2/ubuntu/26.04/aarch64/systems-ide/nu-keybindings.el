;;; nu-keybindings.el --- Nushell mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in nushell-ts-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; nu-lsp doesn't implement document-formatting or code-action providers
;; (confirmed against nushell/nushell's crates/nu-lsp ServerCapabilities), so
;; SPC c a and a format-buffer binding are both omitted here -- they'd just
;; no-op against this server.
;;
;; LOCAL-LEADER — this file's own bindings (SPC m ...):
;;   e e   execute region              (nu-run-region, via `nu -c')
;;   e b   execute buffer              (nu-run-buffer, via `nu FILE')

;;; Code:

(defun nu-run-region ()
  "Run the active region with `nu -c'."
  (interactive)
  (compile (concat "nu -c " (shell-quote-argument (buffer-substring-no-properties (region-beginning) (region-end))))))

(defun nu-run-buffer ()
  "Run the current buffer's file with `nu'."
  (interactive)
  (compile (concat "nu " (shell-quote-argument buffer-file-name))))

(map! :map nushell-ts-mode-map
      :localleader
      (:prefix ("e" . "execute")
       :desc "Execute region" "e" #'nu-run-region
       :desc "Execute buffer" "b" #'nu-run-buffer))

(provide 'nu-keybindings)
;;; nu-keybindings.el ends here
