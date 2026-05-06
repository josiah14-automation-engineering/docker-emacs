;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(setq user-full-name <full-name>
      user-mail-address <email-address>)

(setq doom-theme 'doom-solarized-dark)

(setq org-directory "~/org/")

(setq display-line-numbers-type 'relative)

(map!
 :desc "Move cursor to window left"  :n "C-h" #'evil-window-left
 :desc "Move cursor to window right" :n "C-l" #'evil-window-right
 :desc "Move cursor to window down"  :n "C-j" #'evil-window-down
 :desc "Move cursor to window up"    :n "C-k" #'evil-window-up
 :desc "Delete current window"       :n "C-x w" #'delete-window
 :desc "Find file in project"        :n "C-p" #'project-find-file

 (:leader
  (:prefix "b"
   :desc "Flycheck buffer" :n "c" #'flycheck-buffer)))

(use-package! company
  :config
  (global-company-mode))

(setq vertico-cycle t)

;; C/C++ style
(setq c-default-style "linux"
      c-basic-offset 4)

;; TODO: configure codelldb DAP server for Rust and Zig once codelldb is installed.
;; (setq dap-codelldb-extension-path "<path-to-codelldb-adapter-dir>")
;; (require 'dap-codelldb)

;; TODO: configure dap-gdb-lldb for C/C++ debugging.
;; (require 'dap-gdb-lldb)

;; TODO: configure toml-mode and taplo LSP once taplo binary is installed.
;; (with-eval-after-load 'lsp-mode
;;   (add-to-list 'lsp-language-id-configuration '(toml-mode . "toml"))
;;   (lsp-register-client
;;    (make-lsp-client :new-connection (lsp-stdio-connection "taplo")
;;                     :major-modes '(toml-mode)
;;                     :server-id 'taplo)))
