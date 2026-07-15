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

;; bash-language-server's lsp-mode client checks major-mode against a literal
;; list rather than derived-mode-p, so bats-mode (derived from sh-mode) never
;; matches and lsp! silently no-ops. Register it onto the existing client
;; instead of defining a redundant one, and map it to the "shellscript"
;; language id so the server receives the same protocol id it expects from
;; sh-mode buffers.
;;
;; `lsp--client-major-modes' is only setf-able via a gv-expander that
;; lsp-mode's `cl-defstruct' registers at runtime when lsp-mode.el loads --
;; not at compile time. Since Doom byte-compiles this file without lsp-mode
;; loaded, `cl-pushnew' on that accessor macroexpands into a call to a
;; literal `(setf lsp--client-major-modes)' function that never gets
;; defined, erroring "void-function" the first time this hook runs.
;; `cl-struct-slot-value' sidesteps that: its setf-expander lives in cl-lib
;; itself, so it's always available regardless of load order.
;;
;; `bash-ls' itself isn't registered by loading core `lsp-mode' -- it lives
;; in the separate `clients/lsp-bash.el', which `lsp-mode' only auto-loads
;; once some buffer's major-mode already matches one of its registered
;; modes. A bats-mode buffer never matches (that's the whole problem this
;; file exists to fix), so lsp-bash would never load on its own here.
;; Force it explicitly so `gethash' below actually finds the client.
(after! lsp-mode
  (require 'lsp-bash)
  (cl-pushnew 'bats-mode (cl-struct-slot-value
                          'lsp--client 'major-modes
                          (gethash 'bash-ls lsp-clients)))
  (add-to-list 'lsp-language-id-configuration '(bats-mode . "shellscript")))

;; Doom's own `:lang sh +lsp' module hooks `lsp!' onto `sh-mode-local-vars-
;; hook' (its standard defer-until-after-directory-locals convention), which
;; only fires for buffers whose `major-mode' is literally `sh-mode' -- not
;; for bats-mode, even though it derives from sh-mode. With no Doom :lang
;; module for bats to wire this up, nothing ever calls `lsp!' automatically
;; on a fresh `.bats' buffer; it only worked when called by hand. Mirror
;; Doom's own hook exactly, scoped to bats-mode's own local-vars hook.
(add-hook 'bats-mode-local-vars-hook #'lsp! 'append)

(map! :map bats-mode-map
      :localleader
      (:prefix ("e" . "execute")
       :desc "Run test at point"    "e" #'bats-run-current-test
       :desc "Run current file"     "b" #'bats-run-current-file
       :desc "Run all in directory" "a" #'bats-run-all))

(provide 'bats-keybindings)
