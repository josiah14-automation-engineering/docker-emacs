;;; rust-keybindings.el --- Rust mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in rustic-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   g D         find references         (lsp / xref)
;;   K           hover documentation     (lsp -- rust-analyzer)
;;   ] d / [ d   next / prev diagnostic  (lsp -- rust-analyzer's own
;;                                        diagnostics, clippy-aware)
;;   SPC c a     code actions            (lsp)
;;   SPC c r     rename symbol           (lsp-rename)
;;   SPC b c     flycheck buffer         (config.el global)
;;   SPC d d     start a debug session   (dape -- lldb-dap, see below)
;;
;; `.rs' files use rustic-mode (from the `rustic' package), not plain
;; rust-mode -- Doom's own :lang rust module pulls in rustic for its
;; cargo integration and wires rust-analyzer via lsp-mode automatically
;; (`rustic-mode-local-vars-hook' -> `rustic-setup-lsp', the same
;; `{lang}-mode-local-vars-hook' pattern every other language here uses).
;;
;; Doom's rust module already ships an extensive localleader map of its
;; own for rustic-mode-map (SPC m ...), unlike ruby/js/python -- nothing
;; here needs to duplicate it:
;;   SPC m b a   cargo audit      SPC m b n   cargo new
;;   SPC m b b   cargo build      SPC m b o   cargo outdated
;;   SPC m b B   cargo bench      SPC m b r   cargo run
;;   SPC m b c   cargo check      SPC m t a   cargo test (all)
;;   SPC m b C   cargo clippy     SPC m t t   cargo test (current)
;;   SPC m b d   cargo doc
;;   SPC m b D   cargo doc --open
;;   SPC m b f   cargo fmt
;; (`cargo audit`/`cargo outdated` aren't installed in this image --
;; optional subcommands, not part of the LSP+debugger promise; those two
;; bindings will error with "command not found" if pressed.)
;;
;; Format-on-save uses apheleia's existing default mapping for
;; rustic-mode (rustfmt), unchanged -- no override needed, same as
;; js-mode/typescript-mode.
;;
;; Debugging: dape's built-in lldb-dap config already lists rustic-mode
;; (alongside rust-mode/rust-ts-mode) in its `modes', the same way its
;; gdb config already covers c-mode/c++-mode -- so `SPC d d' just works
;; once lldb is on PATH (installed via apt), no elisp config needed here
;; either.
;;
;; LOCAL-LEADER — this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer -- every other language
;;                        in this image binds bare SPC m f to this; the
;;                        rust module's own SPC m b f (cargo fmt) reaches
;;                        rustfmt via a different path (`cargo fmt`
;;                        itself, not apheleia) but the same end result,
;;                        so this is purely for cross-language muscle-
;;                        memory consistency, not filling a real gap)

;;; Code:

;; Wrapped in `after! rustic-mode' because rustic's own default
;; localleader bindings are wired inside its `use-package! rustic
;; :config' block, which runs lazily on first .rs file visit -- a plain
;; map! call here would run at Doom config-load time instead, before
;; that. Doesn't collide with rustic's own keys, but see go-keybindings.el
;; for the concrete case where this ordering silently clobbered a binding.
(after! rustic-mode
  (map! :map rustic-mode-map
        :localleader
        :desc "Format buffer" "f" #'apheleia-format-buffer))

(provide 'rust-keybindings)
;;; rust-keybindings.el ends here
