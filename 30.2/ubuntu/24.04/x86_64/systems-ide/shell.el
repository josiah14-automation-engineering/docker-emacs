;;; shell.el -*- lexical-binding: t; -*-

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

(provide 'systems-ide-shell)

