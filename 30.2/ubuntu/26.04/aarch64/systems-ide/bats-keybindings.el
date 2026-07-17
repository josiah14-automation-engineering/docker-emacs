;;; bats-keybindings.el --- Bats mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; bats-mode derives from sh-mode (sets sh-shell to bash and wires
;; flycheck's shellcheck checker itself), so the default Doom/LSP bindings
;; documented in sh-keybindings.el apply here too. No after! wrapper is
;; needed -- unlike nix/go, there's no Doom :lang module for bats whose own
;; :config block could race and overwrite these.
;;
;; LOCAL-LEADER — this file's own bindings (SPC m ...):
;;   e e   run test at point           (bats-run-current-test)
;;   e b   run current file            (bats-run-current-file)
;;   e a   run all in directory        (bats-run-all)

;;; Code:

(map! :map bats-mode-map
      :localleader
      (:prefix ("e" . "execute")
       :desc "Run test at point"    "e" #'bats-run-current-test
       :desc "Run current file"     "b" #'bats-run-current-file
       :desc "Run all in directory" "a" #'bats-run-all))

(provide 'bats-keybindings)
;;; bats-keybindings.el ends here
