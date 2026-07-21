;;; javascript-keybindings.el --- JavaScript mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in js-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck -- javascript-oxlint
;;                                        checker, built into flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; Doom's own :lang javascript module wires LSP auto-attach to
;; typescript-language-server automatically (this image installs that
;; plus its `typescript' peer dependency, not deno -- the module's other
;; supported server). Format-on-save uses apheleia's existing default
;; mapping for js-mode (prettier), unchanged -- no override needed here,
;; unlike python-mode/ruby-mode.
;;
;; Linting deliberately uses oxlint, not eslint: flycheck's built-in
;; `javascript-eslint' checker expects a project config file and prints a
;; "missing or incorrect" warning without one (confirmed directly from
;; flycheck's own checker source -- it has a dedicated
;; `flycheck--eslint-handle-suspicious' path just for this case); oxlint
;; (`javascript-oxlint') has no such config-file expectation at all --
;; exactly the zero-config behavior this glue-script tier needs, since
;; there's deliberately no per-project tooling here. eslint itself isn't
;; installed, so flycheck can only select oxlint for js-mode -- no
;; explicit checker-selection override needed.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer, i.e. prettier --
;;                        on-demand, in addition to format-on-save; see
;;                        python-keybindings.el's Commentary for why this
;;                        is apheleia directly rather than
;;                        `lsp-format-buffer')

;;; Code:

(map! :map js-mode-map
      :localleader
      :desc "Format buffer" "f" #'apheleia-format-buffer)

(provide 'javascript-keybindings)
;;; javascript-keybindings.el ends here
