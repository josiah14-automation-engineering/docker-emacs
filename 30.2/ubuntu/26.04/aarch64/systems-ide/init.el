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
       (format +onsave)
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
       debugger
       direnv
       docker
       editorconfig
       (eval +overlay)
       (lookup +dictionary)
       lsp
       magit
       make

       :lang
       (cc +lsp)
       data
       emacs-lisp
       (go +lsp)
       json
       markdown
       (nix +lsp)
       org
       (sh +lsp)
       yaml

       :config
       (default +bindings +smartparens))
