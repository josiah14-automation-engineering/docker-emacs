;;; gerbil-config.el --- Gerbil Scheme mode configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Connects upstream gerbil-mode to Doom's REPL, evaluation, and Company
;; interfaces without treating Gerbil as a Geiser backend.

;;; Code:

;; Gerbil has no Doom :lang flag -- it's a dialect/toolchain layered on
;; Gambit, not a Geiser backend (confirmed against doomemacs's own
;; modules/lang/scheme: no +gerbil flag exists there). packages.el pulls
;; in upstream's own etc/gerbil-mode.el instead of reinventing font-lock/
;; indent rules -- a real `(define-derived-mode gerbil-mode scheme-mode
;; ...)' with its own REPL support via `cmuscheme' (not Geiser).
;;
;; Despite deriving from scheme-mode, gerbil-mode does NOT inherit the
;; +guile/+chez/+gambit REPL/eval wiring Doom's own lang/scheme module
;; sets up for 'scheme-mode -- confirmed directly from doomemacs's
;; modules/tools/eval/autoload/repl.el: `+eval-current-repl-buffer' and
;; `+eval/open-repl-*' resolve a mode's REPL handler via `(assq major-mode
;; +eval-repl-handler-alist)', an exact `eq' lookup keyed on the literal
;; major-mode symbol, not `derived-mode-p'. A gerbil-mode buffer's
;; `major-mode' is the symbol `gerbil-mode', not `scheme-mode', so it
;; needs its own registration below, the same way it would for any other
;; mode with no Doom :lang module of its own.
(after! gerbil-mode
  ;; cmuscheme's `run-scheme' is interactive and prompts for a command
  ;; line; `+gerbil-open-repl' pins that to `gerbil-program-name' (gxi,
  ;; set by gerbil-mode.el itself) so `set-repl-handler!' has a plain
  ;; zero-arg entry point. cmuscheme hardcodes its inferior-process
  ;; buffer name to "*scheme*" (confirmed directly from gerbil-mode.el's
  ;; own `restart-scheme', which switches to that literal buffer name).
  (defun +gerbil-open-repl ()
    "Start (or switch to) the gxi REPL for the current gerbil-mode buffer."
    (run-scheme gerbil-program-name)
    (get-buffer "*scheme*"))

  (defun +gerbil-reload-current-buffer-and-go ()
    "Reload the current Gerbil buffer, then switch to its REPL."
    (gerbil-reload-current-buffer)
    (switch-to-buffer "*scheme*"))

  ;; :send-region / :send-buffer point at gerbil-mode's own redefined
  ;; `scheme-send-region' (start end) and `gerbil-reload-current-buffer'
  ;; (zero args, sends a `(reload "file")' form for the buffer's
  ;; already-saved-to-disk contents to the REPL) -- the closest
  ;; equivalent cmuscheme/gerbil-mode has to Geiser's own
  ;; `geiser-eval-buffer', since cmuscheme has no independent "eval whole
  ;; buffer" primitive. Both signatures already match what
  ;; `+eval-with-repl-fn' calls them with (confirmed directly from
  ;; doomemacs's own repl.el).
  (set-repl-handler! 'gerbil-mode #'+gerbil-open-repl
    :persist t
    :send-region #'scheme-send-region
    :send-buffer #'gerbil-reload-current-buffer)
  (set-eval-handler! 'gerbil-mode #'scheme-send-region))

(after! company
  (require 'company-keywords)

  (defun +gerbil--company-init-h ()
    "Set buffer-local completion behavior for Gerbil."
    (setq-local company-dabbrev-minimum-length 3))

  ;; Gerbil has no semantic completion provider. Reuse Company's Scheme
  ;; vocabulary and add Gerbil's top-level package declaration; dabbrev below
  ;; supplies project-local definitions without coupling completion to a REPL.
  (setf (alist-get 'gerbil-mode company-keywords-alist)
        (cons "package:" (alist-get 'scheme-mode company-keywords-alist)))
  (set-company-backend! 'gerbil-mode
    '(:separate company-keywords company-dabbrev-code)
    'company-capf 'company-yasnippet)
  (add-hook! 'gerbil-mode-hook #'+gerbil--company-init-h))

(provide 'gerbil-config)
;;; gerbil-config.el ends here
