;;; ruby-config.el --- Ruby mode configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Non-keybinding setup for ruby-mode: LSP client selection and
;; formatter wiring. See ruby-keybindings.el for this mode's actual
;; keybindings.

;;; Code:

(after! lsp-mode
  ;; Both `ruby-lsp` and `rubocop --lsp` register as LSP clients for
  ;; ruby-mode (rubocop-ls, rubocop's own built-in LSP mode); rubocop-ls's
  ;; priority (-1) beats ruby-lsp-ls's (-2), so lsp-mode picked rubocop-ls
  ;; alone -- and rubocop's LSP server only implements diagnostics/
  ;; formatting, not completion, silently leaving ruby-mode buffers with
  ;; lsp-mode reporting "on" but zero completion candidates ever offered.
  ;; Disabled so ruby-lsp-ls (the completion-capable server) attaches
  ;; instead; rubocop still runs diagnostics via flycheck's own built-in
  ;; ruby-rubocop checker (see ruby-keybindings.el), so nothing is lost.
  (add-to-list 'lsp-disabled-clients 'rubocop-ls)
  ;; ruby-lsp's own internal bootstrap hard-requires the `bundle`
  ;; executable and a specific pinned gem set (see the Dockerfile's
  ;; BUNDLE_GEMFILE comment for the full story -- this isn't optional the
  ;; way it looks from lsp-ruby-lsp.el's docstring). `t` here makes
  ;; lsp-mode launch `bundle exec ruby-lsp` against that pre-built,
  ;; offline, pinned bundle rather than a bare `ruby-lsp`, which -- with
  ;; the BUNDLE_GEMFILE env var also set globally in the Dockerfile --
  ;; would otherwise skip ruby-lsp's own bootstrap entirely and load
  ;; whatever gem versions happen to be active, unpinned.
  (setq lsp-ruby-lsp-use-bundler t))

;; apheleia (Doom's :editor format backend) defaults ruby-mode to
;; prettier-ruby (an npm-based prettier plugin) -- overridden so
;; ruby-mode uses just one already-installed tool for both linting and
;; formatting, rather than pulling in a second, unrelated Node-based
;; toolchain for formatting alone.
(after! apheleia
  (setf (alist-get 'ruby-mode apheleia-mode-alist) 'rubocop))

(provide 'ruby-config)
;;; ruby-config.el ends here
