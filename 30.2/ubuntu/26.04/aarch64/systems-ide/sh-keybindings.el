;;; sh-keybindings.el --- Shell mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in shell buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; LOCAL-LEADER — this file's own bindings (SPC m ...):
;;   e e   execute region              (sh-execute-region)
;;   e b   execute buffer              (sh-execute-region over the whole buffer)
;;   r r   rename symbol               (lsp-rename)
;;   d d   start debugger              (realgud:zshdb)
;;   s s   switch shell dialect        (sh-set-shell)

;;; Code:

(map! :map sh-mode-map
      :localleader
      (:prefix ("e" . "execute")
       :desc "Execute region" "e" #'sh-execute-region
       :desc "Execute buffer" "b" (cmd! (sh-execute-region (point-min) (point-max))))
      (:prefix ("r" . "refactor")
       :desc "Rename symbol"  "r" #'lsp-rename)
      (:prefix ("d" . "debug")
       ;; realgud:zshdb for zsh; realgud:bashdb for bash if bashdb is installed
       :desc "Start debugger" "d" #'realgud:zshdb)
      (:prefix ("s" . "shell")
       :desc "Switch shell dialect" "s" #'sh-set-shell))

(provide 'sh-keybindings)
;;; sh-keybindings.el ends here
