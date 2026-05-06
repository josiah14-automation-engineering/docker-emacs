;;; init.el -*- lexical-binding: t; -*-

(doom! :completion
       (company +auto)
       (vertico +icons)

       :ui
       doom
       doom-dashboard
       hl-todo
       indent-guides
       modeline
       (popup +defaults)
       treemacs
       unicode
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       snippets

       :emacs
       dired
       electric
       ibuffer
       undo
       vc

       :term
       eshell
       vterm

       :checkers
       syntax

       :tools
       (debugger +lsp)
       direnv
       docker
       editorconfig
       (eval +overlay)
       (lookup +dictionary)
       lsp
       magit
       make

       :lang
       data
       emacs-lisp
       json
       markdown
       org
       yaml

       :config
       (default +bindings +smartparens))
