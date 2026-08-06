;;; all-lisps-config.el --- Shared Lisp tooling configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Editing settings shared by the Lisp-family language integrations.
;; Keep dialect-specific configuration in its corresponding config file.

;;; Code:

;; Keep Doom's nested `map!' DSL indented like a one-argument body form.
(put ':prefix 'lisp-indent-function 1)

(provide 'all-lisps-config)
;;; all-lisps-config.el ends here
