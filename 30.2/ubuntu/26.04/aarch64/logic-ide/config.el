;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name <full-name>
      user-mail-address <email-address>)

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "SourceCodePro Nerd Font" :size 16 :weight 'medium))
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; An earlier version of this line used "SRC-Hack Nerd Font Mono" -- a font
;; family that exists on the *host* Emacs install this was measured against,
;; but not in this container's own font set at all (`fc-list` here only has
;; plain "Hack", not that compound Nerd Font name). An unresolvable
;; `doom-font' derails Doom's startup far beyond just the font: the leader
;; key stopped responding and the theme rendered as some unstyled default,
;; both symptoms of `doom-init-fonts-h' erroring and aborting the rest of
;; that startup hook. "Fira Code" is confirmed present here (`fonts-firacode`
;; is already an explicit apt dependency below) -- verify any future font
;; choice with `fc-list` inside the actual target image, not another host.
(setq doom-font (font-spec :family "Fira Code" :size 14))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-solarized-dark)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFAULT MAPPINGS
;;
;; Evil Normal Mode:
;; gd  - +lookup/definition (dumb-jump fallback, no LSP)
;; gD  - +lookup/references
;; K   - +lookup/documentation
;; gcc - comment line
;; gc  - comment region/selection
;; SPC c r   - rename all occurrences of symbol under cursor
;; SPC o p   - Open Treemacs project file navigation sidebar
;; SPC o P   - Open Treemacs project file navigation sidebar without switching
;;             focus to it
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(map!
 :desc "Move the cursor to new COUNT-th window left of the current one" :n "C-h" #'evil-window-left
 :desc "Move the cursor to new COUNT-th window right of the current one" :n "C-l" #'evil-window-right
 :desc "Move the cursor to new COUNT-th window down of the current one" :n "C-j" #'evil-window-down
 :desc "Move the cursor to new COUNT-th window up of the current one" :n "C-k" #'evil-window-up
 :desc "Delete current window" :n "C-x w" #'delete-window
 :desc "Find file in project" :n "C-p" #'project-find-file

 (:leader
  (:prefix "b"
   :desc "Flycheck buffer" :n "c" #'flycheck-buffer)))

;; Company configuration
(use-package! company
  :config
  (global-company-mode))

(setq vertico-cycle t) ; enables cycling to key past history into fuzzy-matched commands

;; manually set the icon for code actions as it does not render properly by
;; default
(after! lsp-mode
  (setq lsp-modeline-code-action-fallback-icon
        (nerd-icons-codicon "nf-cod-lightbulb")))

(load! "mercury")
(load! "mercury-keybindings")
(load! "prolog")
(load! "prolog-keybindings")
(load! "nix-keybindings")

