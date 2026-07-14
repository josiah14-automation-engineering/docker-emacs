;;; bats-keybindings.el -*- lexical-binding: t; -*-

;; bats-mode derives from sh-mode (sets sh-shell to bash and wires
;; flycheck's shellcheck checker itself), so the default Doom/LSP bindings
;; documented in sh-keybindings.el apply here too. No after! wrapper is
;; needed -- unlike nix/go, there's no Doom :lang module for bats whose own
;; :config block could race and overwrite these.

;; sh-script.el also claims .bats -> sh-mode, as a plain top-level form (not
;; an autoload cookie), so it only fires once sh-script.el is actually
;; require'd. Deferring our own fix to with-eval-after-load leaves a cold-start
;; gap: on a fresh Emacs, the first .bats file opened is itself what triggers
;; sh-script's autoload, so its entry wins that one race before our hook can
;; run. Force the require eagerly here, then correct it immediately, so the
;; fix is already in place before any .bats file is ever opened.
(require 'sh-script)
(setf (alist-get "\\.bats\\'" auto-mode-alist nil nil #'equal) 'bats-mode)

(map! :map bats-mode-map
      :localleader
      (:prefix ("e" . "execute")
       :desc "Run test at point"    "e" #'bats-run-current-test
       :desc "Run current file"     "b" #'bats-run-current-file
       :desc "Run all in directory" "a" #'bats-run-all))

(provide 'bats-keybindings)
