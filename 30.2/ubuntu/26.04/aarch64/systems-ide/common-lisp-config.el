;;; common-lisp-config.el --- Common Lisp configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Keeps Sly startup compatible with this image's SBCL-only installation.

;;; Code:

;; These contribs require Lisp systems absent from this image and otherwise
;; drop startup into SLDB. Keep the self-contained contribs enabled.
(after! sly
  (setq sly-contribs (remove 'sly-quicklisp
                             (remove 'sly-stepper sly-contribs))))

(defun +common-lisp--font-lock-h ()
  "Enable Emacs's complete Common Lisp syntax highlighting level."
  (setq-local font-lock-defaults
              (cons 'lisp-cl-font-lock-keywords-2
                    (cdr font-lock-defaults)))
  (font-lock-add-keywords
   nil
   `((,(concat "("
               (regexp-opt '("setq" "setf" "psetq" "psetf" "shiftf"
                             "rotatef" "incf" "decf" "push" "pushnew"
                             "pop" "remf" "multiple-value-setq") t)
               "\\_>")
      1 font-lock-keyword-face))))

(add-hook! 'lisp-mode-hook #'+common-lisp--font-lock-h)

(after! company
  (defun +common-lisp--company-init-h ()
    "Include definitions in the current Common Lisp buffer."
    (setq-local company-dabbrev-minimum-length 2))

  (set-company-backend! 'lisp-mode
    '(:separate company-capf company-dabbrev-code)
    'company-yasnippet)
  (add-hook! 'lisp-mode-hook #'+common-lisp--company-init-h))

(provide 'common-lisp-config)
;;; common-lisp-config.el ends here
