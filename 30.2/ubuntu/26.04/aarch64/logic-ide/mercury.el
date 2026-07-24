;;; mercury.el -*- lexical-binding: t; -*-

;; No LSP server exists for Mercury. Navigation is via dumb-jump (configured by
;; the lookup module). Error checking is via flycheck with mmc.

(use-package! metal-mercury-mode
  :mode "\\.m\\'")

;; flycheck-mercury defines checker mercury-mmc with a custom error parser
;; tuned to mmc's output format (colon-delimited, no fixed column field).
;; Its :modes list includes metal-mercury-mode explicitly, so auto-selection works.
;; mmc is invoked as: mmc -e --infer-all <source>
;;   -e          — check only; no .c/.o side effects
;;   --infer-all — infer types/modes/determinism rather than requiring full annotations
(use-package! flycheck-mercury
  :after flycheck)

(add-hook! metal-mercury-mode
  (flycheck-mode +1))

;; The Doom Emacs default is to assume .m files are objective-c. However, in the case
;; for this IDE, we want to assume they're Mercury code since this IDE is provisioned
;; for work in the logic-paradigm family of programming languages. The first line
;; corrects the display icon for dired, treemacs, and tabs (the extension-based rendering),
;; the second line fixes doom-modeline's buffer icon which is mode-based.
(after! nerd-icons
  (setf (alist-get "m" nerd-icons-extension-icon-alist nil nil #'equal)
        (list 'nerd-icons-faicon "nf-fa-mercury" :face 'nerd-icons-orange))
  (add-to-list 'nerd-icons-mode-icon-alist
               '(metal-mercury-mode nerd-icons-faicon "nf-fa-mercury" :face nerd-icons-orange)))
