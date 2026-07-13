;;; go-config.el --- Go mode configuration -*- lexical-binding: t; -*-

;;; Code:

(use-package! flycheck-golangci-lint
  :hook (go-mode . flycheck-golangci-lint-setup))

(provide 'go-config)
;;; go-config.el ends here
