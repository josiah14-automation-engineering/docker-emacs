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
