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
       (cc +lsp)              ; C/C++ — clangd
       (rust +lsp)            ; Rust — rust-analyzer via rustup
       zig                    ; Zig — zls
       (sh +lsp)              ; Shell — bash-language-server
       (lua +lsp)             ; Lua — lua-language-server
       nix                    ; Nix — nil LSP
       (scheme +guile)        ; Guile/Scheme — Geiser REPL integration
       cmake                  ; CMake — cmake-language-server
       (python)               ; Python — syntax only, no LSP
       (go)                   ; Go — syntax only, no LSP
       ruby                   ; Ruby — syntax only
       perl                   ; Perl — syntax only
       asm                    ; Assembly — x86/ARM syntax
       data                   ; JSON, CSV, etc.
       emacs-lisp
       markdown
       org
       json
       yaml

       :config
       (default +bindings +smartparens))
