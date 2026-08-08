;;; scheme-config.el --- Geiser multi-backend configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Keeps Chez, Gambit, and Guile distinguishable under Geiser and ensures
;; Geiser activates only for literal scheme-mode buffers.

;;; Code:

;; .ss is shared by Chez and Gerbil.  Gerbil's `def' form is a useful content
;; signal; otherwise let Scheme/Geiser inspect the buffer and prompt if its
;; own content heuristics cannot distinguish an implementation.
(defun +scheme-gerbil-ss-buffer-p ()
  "Return non-nil for a .ss buffer containing a Gerbil `def' form."
  (and buffer-file-name
       (string-match-p "\\.ss\\'" buffer-file-name)
       (save-excursion
         (goto-char (point-min))
         (re-search-forward "^[[:space:]]*(def[[:space:]\n]" nil t))))

(defun +scheme-chez-ss-buffer-p ()
  "Return non-nil for a .ss buffer containing a Chez-specific marker."
  (and buffer-file-name
       (string-match-p "\\.ss\\'" buffer-file-name)
       (+geiser-chez-buffer-p)))

(defun +scheme-chez-mode ()
  "Enter `scheme-mode' with Chez selected before mode hooks run."
  (delay-mode-hooks
    (scheme-mode)
    (setq-local geiser-scheme-implementation 'chez)))

(add-to-list 'magic-mode-alist '(+scheme-gerbil-ss-buffer-p . gerbil-mode))
(add-to-list 'magic-mode-alist '(+scheme-chez-ss-buffer-p . +scheme-chez-mode))
(add-to-list 'auto-mode-alist '("\\.ss\\'" . scheme-mode))
(add-to-list 'auto-mode-alist '("\\.def\\'" . scheme-mode))

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

(defun +geiser-chez-buffer-p ()
  "Ascertain whether the current buffer holds Chez Scheme code.
Same cost profile as `geiser-guile--guess': a single bounded
`re-search-forward' from `point-min', nothing more expensive."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward +geiser-chez-guess-re nil t)))

(defun +geiser-gambit-buffer-p ()
  "Ascertain whether the current buffer has Gambit-specific markers."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward "\\_<\\(?:gambit\\|gsi\\)\\_>" nil t)))

;; HACK: Geiser exposes no public registration API for implementation methods.
(after! geiser-chez
  ;; Upstream registers .ss as unconditionally Chez, but this image also
  ;; supports Gerbil's .ss files.  Content wins; an ambiguous file prompts.
  (setq geiser-implementations-alist
        (cl-remove-if
         (lambda (entry)
           (and (eq (cadr entry) 'chez)
                (equal (car entry) '(regexp "\\.ss\\'"))))
         geiser-implementations-alist))
  ;; `geiser-impl--method' resolves via a plain `assq' over this list
  ;; (`geiser-impl--methods' / `geiser-impl--registry'), so pushing a new
  ;; `check-buffer' entry onto the front of Chez's own methods list
  ;; shadows cleanly -- no need to touch or re-register anything else
  ;; `geiser-chez''s own `define-geiser-implementation' already set up.
  (let ((implementation (assq 'chez geiser-impl--registry)))
    (setcdr implementation
            (cons (list 'check-buffer #'+geiser-chez-buffer-p)
                  (assq-delete-all 'check-buffer (cdr implementation))))))

(after! geiser-gambit
  (let ((implementation (assq 'gambit geiser-impl--registry)))
    (setcdr implementation
            (cons (list 'check-buffer #'+geiser-gambit-buffer-p)
                  (assq-delete-all 'check-buffer (cdr implementation))))))

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
(defun +geiser--remember-implementation-a (impl)
  "Offer to remember the selected Scheme implementation, then return IMPL."
  (when (and buffer-file-name
             (y-or-n-p
              (format "Remember `%s' as this directory's Scheme implementation? " impl)))
    (add-dir-local-variable 'scheme-mode 'geiser-scheme-implementation impl)
    (save-buffer))
  impl)

;; HACK: Geiser has no public hook after interactive implementation selection.
(advice-remove 'geiser-impl--read-impl #'+geiser--remember-implementation-a)
(advice-add 'geiser-impl--read-impl :filter-return
            #'+geiser--remember-implementation-a)

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
    ;; A dialect-marked file may be the first Scheme buffer opened.  Load
    ;; every configured detector before Geiser attempts its initial guess.
    (require 'geiser-chez)
    (require 'geiser-gambit)
    (require 'geiser-guile)
    (geiser-mode)))

(add-hook! 'scheme-mode-hook #'+geiser--activate-mode-h)

(after! company
  (defun +scheme-company-project-symbols (command &optional arg &rest _)
    "Complete Scheme definitions found beneath the current file directory."
    (pcase command
      ('interactive (company-begin-backend #'+scheme-company-project-symbols))
      ('prefix (and (derived-mode-p 'scheme-mode) (company-grab-symbol)))
      ('candidates
       (let (symbols)
         (dolist (file (directory-files-recursively
                        default-directory "\\.\\(?:scm\\|ss\\|sld\\|def\\)\\'"))
           (with-temp-buffer
             (insert-file-contents file)
             (goto-char (point-min))
             (while (re-search-forward
                     "^[[:space:]]*(define\\(?:-syntax\\)?[[:space:]]+\\(?:([[:space:]]*\\)?\\([^][()[:space:]]+\\)"
                     nil t)
               (push (match-string-no-properties 1) symbols))))
         (all-completions arg (delete-dups symbols))))))

  (defun +scheme--company-init-h ()
    "Include symbols defined in the current Scheme buffer in completion."
    (setq-local company-dabbrev-minimum-length 2))

  (set-company-backend! 'scheme-mode
    '(:separate company-capf company-keywords
                +scheme-company-project-symbols company-dabbrev-code)
    'company-yasnippet)
  (add-hook! 'scheme-mode-hook #'+scheme--company-init-h))

(provide 'scheme-config)
;;; scheme-config.el ends here
