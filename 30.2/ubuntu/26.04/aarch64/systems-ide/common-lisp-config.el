;;; common-lisp-config.el --- Common Lisp configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Keeps Sly startup compatible with this image's SBCL-only installation.

;;; Code:

;; These contribs require Lisp systems absent from this image and otherwise
;; drop startup into SLDB. Keep the self-contained contribs enabled.
(after! sly
  (setq sly-contribs (remove 'sly-quicklisp
                             (remove 'sly-stepper sly-contribs))))

(provide 'common-lisp-config)
;;; common-lisp-config.el ends here
