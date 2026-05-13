;;; sh-keybindings.el -*- lexical-binding: t; -*-

;; Default Doom/LSP bindings active in shell buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC b c     flycheck buffer         (config.el global)

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
