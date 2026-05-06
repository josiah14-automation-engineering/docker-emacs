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
