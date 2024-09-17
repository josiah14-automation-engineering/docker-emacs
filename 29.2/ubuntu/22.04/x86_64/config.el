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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Additional hooks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(after! lsp-mode
  (add-hook! lsp-lens-mode)
  (add-hook! lsp-dired-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEFAULT MAPPINGS
;;
;; Evil Normal Mode:
;; gd - lsp-find-definition
;; gD - lsp-find-references
;; K  - lsp-describe-thing-at-point
;; gcc - comment line
;; gc - comment region/selection
;; Spc-c-r - rename all occurences of symbol under cursor
;; Scc-o-p - Open Treemacs project file navigation sidebar
;; Scc-o-P - Open Treemacs project file navigation sidebar without switching
;;           focus to it
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

;;(map!
;; :leader
;; :map scala-mode-map
;; ; Main top-level keys
;; "= =" #'lsp-format-buffer
;; "m t" #'lsp-ui-doc-show
;; "m T" #'lsp-describe-thing-at-point
;; "m C-t" #'lsp-ui-doc-mode

 ; Lens-mode
;; "m l s" #'lsp-lens-show
;; "m l h" #'lsp-lens-hide
;; "m l a" #'lsp-avy-lens

 ; DAP debugging mode keys
;; "m d x" #'dap-delete-session
;; "m d X" #'dap-delete-all-sessions
;; "m d s" #'dap-start-debugging
;; "m d n" #'dap-next
;; "m d i" #'dap-step-in
;; "m d o" #'dap-step-out
;; "m d c" #'dap-continue
;; "m d b u" #'dap-ui-breakpoints
;; "m d b L" #'dap-ui-breakpoints-list
;; "m d b a" #'dap-breakpoint-add
;; "m d b r" #'dap-breakpoint-delete
;; "m d b R" #'dap-breakpoint-delete-all
;; "m d b t" #'dap-breakpoint-toggle
;; "m d b c" #'dap-breakpoint-condition)
