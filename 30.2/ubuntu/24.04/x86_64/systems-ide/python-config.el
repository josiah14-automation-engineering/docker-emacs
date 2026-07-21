;;; python-config.el --- Python mode configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Non-keybinding setup for python-mode: formatter wiring. See
;; python-keybindings.el for this mode's actual keybindings.

;;; Code:

;; apheleia (Doom's :editor format backend) defaults python-mode to
;; black -- overridden so python-mode uses just one already-installed
;; tool for both linting and formatting, rather than pulling in a
;; second, unrelated toolchain (black needs its own pip/pipx install)
;; for formatting alone.
(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff))

(provide 'python-config)
;;; python-config.el ends here
