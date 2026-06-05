;;; global-keybindings.el --- Global keybindings -*- lexical-binding: t; -*-

;;; Commentary:
;; Global keybindings active in all buffers.
;;
;;   C-h           move cursor to window left    (evil-window-left)
;;   C-l           move cursor to window right   (evil-window-right)
;;   C-j           move cursor to window down    (evil-window-down)
;;   C-k           move cursor to window up      (evil-window-up)
;;   C-x w         delete current window
;;   C-p           find file in project          (project-find-file)
;;   SPC b c       flycheck current buffer
;;
;; LSP server management — SPC c l opens lsp-command-map, then:
;;   SPC c l w r   restart LSP server            (lsp-workspace-restart)
;;   SPC c l w d   describe session              (lsp-describe-session)
;;   SPC c l w q   shutdown LSP server           (lsp-workspace-shutdown)
;;   SPC c l w D   disconnect                    (lsp-disconnect)
;;
;; LSP toggles — SPC c l T ...:
;;   SPC c l T l   toggle lenses                 (lsp-lens-mode)
;;   SPC c l T d   toggle documentation popup   (lsp-ui-doc-mode)
;;   SPC c l T b   toggle breadcrumb             (lsp-headerline-breadcrumb-mode)
;;   SPC c l T h   toggle symbol highlighting   (lsp-toggle-symbol-highlight)

;;; Code:

(map!
 :desc "Move cursor to window left"  :n "C-h" #'evil-window-left
 :desc "Move cursor to window right" :n "C-l" #'evil-window-right
 :desc "Move cursor to window down"  :n "C-j" #'evil-window-down
 :desc "Move cursor to window up"    :n "C-k" #'evil-window-up
 :desc "Delete current window"       :n "C-x w" #'delete-window
 :desc "Find file in project"        :n "C-p" #'project-find-file

 (:leader
  (:prefix "b"
   :desc "Flycheck buffer" :n "c" #'flycheck-buffer)))

;; Local Variables:
;; no-byte-compile: t
;; End:

(provide 'global-keybindings)
;;; global-keybindings.el ends here
