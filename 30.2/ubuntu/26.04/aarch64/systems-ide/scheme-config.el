;;; scheme-config.el --- Geiser multi-backend (Chez/Gambit/Guile) configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Keeps Chez, Gambit, and Guile distinguishable under Geiser and ensures
;; Geiser activates only for literal scheme-mode buffers.

;;; Code:

;; With all three of `+chez +gambit +guile' active, `geiser-impl--guess'
;; loses its single-backend fast path and falls through to every
;; disambiguation heuristic in turn. Gambit and Guile each ship their own
;; `check-buffer' content heuristic; Chez ships none at all (confirmed
;; absent from `geiser-chez.el' itself) -- so any Chez file with no other
;; distinguishing marker fell all the way through to `geiser-mode.el''s
;; unconditional interactive prompt, which hangs the entire (single-
;; threaded) daemon under a frame-less `emacsclient --eval' call. Full
;; root cause in DECISIONLOG.md ("Multi-backend Geiser ... hangs the
;; whole daemon").
;;
;; Fix, part 1: give Chez the same kind of `check-buffer' heuristic
;; Gambit/Guile already have. Markers confirmed via GitHub code search
;; against `cisco/ChezScheme' itself: the `(chezscheme)' library name
;; (as in `(import (chezscheme))') and Chez's own `#!eof'/`#!bwp' reader
;; syntax -- both essentially unique to Chez among the three.
(defconst +geiser-chez-guess-re "(chezscheme)\\|#!\\(?:eof\\|bwp\\)"
  "Regexp matching Chez-specific source markers.")

(defun +geiser-chez-check-buffer ()
  "Ascertain whether the current buffer holds Chez Scheme code.
Same cost profile as `geiser-guile--guess': a single bounded
`re-search-forward' from `point-min', nothing more expensive."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward +geiser-chez-guess-re nil t)))

(after! geiser-chez
  ;; `geiser-impl--method' resolves via a plain `assq' over this list
  ;; (`geiser-impl--methods' / `geiser-impl--registry'), so pushing a new
  ;; `check-buffer' entry onto the front of Chez's own methods list
  ;; shadows cleanly -- no need to touch or re-register anything else
  ;; `geiser-chez''s own `define-geiser-implementation' already set up.
  (push (list 'check-buffer #'+geiser-chez-check-buffer)
        (cdr (assq 'chez geiser-impl--registry))))

;; Fix, part 2: once a file genuinely has no detectable marker for any
;; of the three, `geiser-impl--guess' still falls through to the
;; interactive prompt (`geiser-impl--read-impl') -- fine for a human at
;; a real frame, since that's the only remaining ambiguous case. Offer
;; to persist the answer via `.dir-locals.el' so the same directory
;; never asks twice: `geiser-scheme-implementation' is already a
;; buffer-local var Geiser's own guess sequence checks first (right
;; after an already-resolved cached value) and is already marked
;; `safe-local-variable', so nothing new is needed to make Geiser
;; *read* it back -- only this write path.
(advice-add 'geiser-impl--read-impl :filter-return
            (lambda (impl)
              (when (and buffer-file-name
                         (y-or-n-p
                          (format "Remember `%s' as this directory's Scheme implementation? "
                                  impl)))
                (add-dir-local-variable 'scheme-mode 'geiser-scheme-implementation impl)
                (save-buffer))
              impl))

;; Fix, part 3: even once an implementation is resolved (marker,
;; dir-locals, or answered prompt), `geiser-eval-definition' and the
;; rest of the localleader `e ...' map stay void until `geiser-mode'
;; itself turns on. Geiser ships its own `;;;###autoload (add-hook
;; 'scheme-mode-hook #'geiser-mode--maybe-activate)', and that line is
;; present in Doom's compiled loaddefs, but empirically `geiser-mode'
;; does not end up active on scheme-mode buffers in this image (exact
;; mechanism for the gap not pinned down -- confirmed not an
;; autoload-generation bug, since the hook line is there). Activate Geiser
;; explicitly for literal `scheme-mode' buffers while preserving the upstream
;; guard for derived modes such as `gerbil-mode'.
(defun +geiser--activate-mode-h ()
  "Activate Geiser only in a literal `scheme-mode' buffer."
  (when (eq major-mode 'scheme-mode)
    (geiser-mode)))

(add-hook! 'scheme-mode-hook #'+geiser--activate-mode-h)

(provide 'scheme-config)
;;; scheme-config.el ends here
