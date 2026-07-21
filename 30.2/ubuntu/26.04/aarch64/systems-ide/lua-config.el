;;; lua-config.el --- Lua mode configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Non-keybinding setup for lua-mode: points lsp-mode at this image's
;; actual lua-language-server install location and narrows lua-mode's
;; LSP client selection down to it. See lua-keybindings.el for this
;; mode's actual keybindings.

;;; Code:

(after! lsp-mode
  ;; lsp-mode's own default install path for lua-language-server is a
  ;; `.cache/lsp/` directory under $EMACSDIR that has shifted convention
  ;; across lsp-mode versions -- pointed explicitly at this image's fixed
  ;; install location instead of betting on hitting the current default
  ;; correctly. The `main.lua` sibling and `locale/` directory are on
  ;; disk at that path either way, since the whole release archive was
  ;; extracted as a tree, not just this one binary copied out -- but
  ;; `lsp-clients-lua-language-server-main-location' is its own separate
  ;; defcustom, derived from `-install-dir' by default, not from `-bin';
  ;; overriding `-bin' alone doesn't fix it. Left unset for a long time
  ;; without visibly breaking anything -- the client's own `:test?'
  ;; function checks both paths and had presumably been failing all
  ;; along, just never actually reached this obviously because it always
  ;; had other, also-untested candidates (emmy-lua/lsp-lua-lsp/
  ;; lua-roblox-language-server, all disabled below) to fall through to
  ;; first. Disabling those surfaced it for real: with lua-language-server
  ;; as the only remaining candidate and its own test still failing,
  ;; `lsp' tried to auto-download it from api.github.com instead --
  ;; harmless in intent, but this container has no general network
  ;; access, so it just hangs on DNS resolution until it times out.
  (setq lsp-clients-lua-language-server-bin
        (expand-file-name "~/.local/lib/lua-language-server/bin/lua-language-server")
        lsp-clients-lua-language-server-main-location
        (expand-file-name "~/.local/lib/lua-language-server/main.lua"))

  ;; lsp-mode bundles four LSP clients that all activate on lua-mode --
  ;; only lua-language-server is actually installed in this image. Without
  ;; this, `SPC c l w s' (or any auto-attach) can end up trying
  ;; lua-roblox-language-server or emmy-lua instead (neither installed,
  ;; both fail differently -- roblox tries to auto-download like the bug
  ;; above, emmy-lua needs a Java runtime this image doesn't have).
  ;; `C-u SPC c l w s' still prompts to choose explicitly among whatever's
  ;; left enabled, if lua-language-server itself ever needs bypassing.
  (dolist (client '(emmy-lua lsp-lua-lsp lua-roblox-language-server))
    (add-to-list 'lsp-disabled-clients client)))

(provide 'lua-config)
;;; lua-config.el ends here
