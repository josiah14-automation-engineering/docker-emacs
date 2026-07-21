;;; polyglot-keybindings.el --- Cross-language dev-tooling keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Keybindings that aren't specific to any one language's own
;; <lang>-keybindings.el, but aren't purely editor-level either (see
;; global-keybindings.el for that) -- cross-cutting development-tooling
;; concerns that show up across multiple languages' LSP/project setups.
;;
;;   SPC c l w S   force lsp-mode's interactive root picker
;;                 (lsp-pick-root)
;;
;; `lsp-auto-guess-root' (config.el, needed for the daemon/smoketest
;; flow) short-circuits lsp-mode's own interactive root-selection prompt
;; entirely -- `lsp--calculate-root' tries `lsp--suggest-project-root'
;; (Projectile/project.el's guess) first, and only ever reaches
;; `lsp--find-root-interactively' when auto-guess is off. `SPC c l w s'
;; (plain `lsp', already bound by lsp-mode itself) just re-runs the same
;; guess. This binding reaches the real prompt instead -- import
;; suggested root, select a root directory interactively, import at the
;; current directory, or blocklist -- without touching the global
;; setting the smoketest flow depends on, since the override is
;; buffer-local. Comes up whenever the auto-guessed root is wrong for a
;; project nested inside a bigger VCS tree in a shape
;; `projectile-project-root-files-bottom-up' doesn't already cover (see
;; DECISIONLOG.md's "LSP workspace-root detection" entry) -- or for any
;; multi-root/multi-util case where you want to point a single language
;; server at a specific directory rather than whatever it guessed.

;;; Code:

(defun lsp-pick-root ()
  "Force lsp-mode's interactive root picker for the current buffer.
Buffer-locally disables `lsp-auto-guess-root' just long enough to reach
`lsp--find-root-interactively', then calls `lsp' interactively. Does not
touch the global `lsp-auto-guess-root' setting."
  (interactive)
  (setq-local lsp-auto-guess-root nil)
  (call-interactively #'lsp))

(defun lsp-restore-auto-guess-root ()
  "Restore automatic root-guessing for the current buffer.
`lsp-pick-root' disables `lsp-auto-guess-root' buffer-locally so it can
reach lsp-mode's interactive root prompt -- there's no other built-in
way to undo that override for a single buffer once it's set. This
kills the buffer-local binding entirely, reverting to whatever
`lsp-auto-guess-root' is set to globally."
  (interactive)
  (kill-local-variable 'lsp-auto-guess-root))

(map! :leader
      (:prefix "c"
        (:prefix "l"
          (:prefix "w"
           :desc "Pick root interactively" "S" #'lsp-pick-root))))

(provide 'polyglot-keybindings)
;;; polyglot-keybindings.el ends here
