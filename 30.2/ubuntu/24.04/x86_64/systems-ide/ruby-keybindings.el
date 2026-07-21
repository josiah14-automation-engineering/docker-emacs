;;; ruby-keybindings.el --- Ruby mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in ruby-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck -- ruby-rubocop
;;                                        checker, built into flycheck)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; Doom's own :lang ruby module wires LSP auto-attach automatically.
;; ruby-lsp (Shopify's, the modern/actively-maintained choice -- solargraph
;; is not installed in this image, so there's no ambiguity between the
;; two) runs as `bundle exec ruby-lsp' against a fixed, pre-built, offline
;; bundle (`lsp-ruby-lsp-use-bundler' is t in config.el) -- ruby-lsp's own
;; internal bootstrap hard-requires `bundle' regardless of project
;; structure, so unlike every other language in this glue-script tier,
;; plain no-bundler/no-Gemfile invocation isn't actually an option here;
;; see the Dockerfile's BUNDLE_GEMFILE comment for the full story. rubocop
;; also registers its own `rubocop --lsp' LSP client (rubocop-ls); it's
;; disabled in config.el since it only provides diagnostics/formatting,
;; not completion, and would otherwise silently win the client-priority
;; contest against ruby-lsp-ls.
;; Format-on-save runs rubocop's own `-a'/autocorrect (config.el overrides
;; apheleia's own default of prettier-ruby, an npm-based plugin, for
;; ruby-mode) -- one Ruby-native tool doing both linting and formatting,
;; no Node dependency pulled in just to format Ruby.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer, i.e. rubocop -a --
;;                        on-demand, in addition to format-on-save; see
;;                        python-keybindings.el's Commentary for why this
;;                        is apheleia directly rather than
;;                        `lsp-format-buffer')

;;; Code:

(map! :map ruby-mode-map
      :localleader
      :desc "Format buffer" "f" #'apheleia-format-buffer)

(provide 'ruby-keybindings)
;;; ruby-keybindings.el ends here
