;;; shell-config.el --- Shell (Bash/Zsh/Ksh) mode configuration -*- lexical-binding: t; -*-

;;; Code:

(setq lsp-bash-shellcheck-arguments "-x")

;; Associate Bash, Zsh, and Ksh system config files and scripts to their proper modes
;; using file extension.

(defun register-shell-file-patterns (patterns mode)
  (dolist (file-extension-pattern patterns)
    (add-to-list 'auto-mode-alist (cons file-extension-pattern mode))))

(define-derived-mode bash-mode sh-mode "BASH"
  (sh-set-shell "bash"))
(define-derived-mode zsh-mode sh-mode "ZSH"
  (sh-set-shell "zsh"))
(define-derived-mode ksh-mode sh-mode "KSH"
  (sh-set-shell "ksh"))

;; `sh-set-shell' only updates `sh-shell-file' when explicitly rewriting a
;; buffer's shebang line (`insert-flag' non-nil, per sh-script.el's own
;; source) -- the automatic dialect detection that runs for every
;; sh-mode/bash-mode/zsh-mode/ksh-mode buffer calls `(sh-set-shell
;; (sh--guess-shell) nil nil)', leaving `sh-shell-file' at its global
;; default regardless of what dialect was actually detected. `sh-shell'
;; itself IS reliably correct (`sh--guess-shell' reads the buffer's own
;; shebang line directly) -- `sh-shell-file' just never gets synced to it.
;; This silently breaks `sh-execute-region' (and this project's own
;; execute-region/execute-buffer localleader bindings in
;; sh-keybindings.el, both of which call it): a bash-shebanged script runs
;; through the global default shell instead, which on this image is
;; `/bin/sh' (dash) -- failing on any bash-only syntax (`[[', arrays,
;; `${var:-default}', etc.).
(defun +shell--sync-shell-file ()
  "Set buffer-local `sh-shell-file' to match the already-detected `sh-shell'."
  (setq-local sh-shell-file (symbol-name sh-shell)))

(add-hook 'sh-mode-hook #'+shell--sync-shell-file)

(dolist (config '((bash-mode "\\.bash\\'"
                             "\\.bashrc\\'"
                             "\\.bash_aliases\\'"
                             "\\.bash_profile\\'"
                             "\\.bash_login\\'"
                             "\\.bash_logout\\'")
                  (zsh-mode "\\.zsh\\'"
                            "\\.zsh-theme\\'"
                            "\\.plugin\\.zsh\\'"
                            "\\.zshrc\\'"
                            "\\.zshenv\\'"
                            "\\.zprofile\\'"
                            "\\.zlogin\\'"
                            "\\.zlogout\\'")
                  (ksh-mode "\\.ksh\\'"
                            "\\.kshrc\\'")))
  (register-shell-file-patterns (cdr config) (car config)))

(provide 'shell-config)
;;; shell-config.el ends here
