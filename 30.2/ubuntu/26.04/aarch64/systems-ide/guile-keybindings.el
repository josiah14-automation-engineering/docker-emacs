;;; guile-keybindings.el --- Guile Scheme mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Doom's own `:lang scheme +guile' module (see init.el) already wires an
;; extensive localleader map for scheme-mode-map -- nothing here duplicates
;; it. Default Doom/Geiser bindings active in scheme-mode buffers (reference):
;;   g d         go to definition          (geiser-edit-symbol-at-point)
;;   K           hover documentation       (geiser-doc-symbol-at-point)
;;   SPC b c     flycheck buffer           (config.el global,
;;                                          `flycheck-guile' auto-activates)
;;
;; LOCALLEADER (SPC m ...), already provided by Doom's scheme module:
;;   '   toggle REPL              r f   find file in REPL's module
;;   "   connect to REPL          r r   switch to REPL
;;   [   squarify                 r b   send buffer to REPL
;;   \   insert lambda             e b   eval buffer
;;   s   set implementation       e B   eval buffer and switch
;;   R   reload                   e e   eval last sexp
;;   h <  h >  h a  h s  h m  h .  e d   eval defun
;;     (help lookups, module/symbol xref)  e D   eval defun and switch
;;   c   close REPL buffer        e r   eval region
;;   q   quit REPL                e R   eval region and switch
;;   m / M   macro expand / expand-1
;;
;; Debugging: Geiser's own debug menu (`,' inside the REPL once it enters
;; debug mode -- breakpoints, tracepoints, clickable backtraces in a
;; `*Geiser Dbg*' popup) is the reference implementation Geiser's debugger
;; design was modeled on for other Schemes -- already fully wired by Doom's
;; module, nothing to add here.
;;
;; LOCAL-LEADER -- this file's own binding (SPC m ...):
;;   f   format buffer   (apheleia-format-buffer -- every other language
;;                        in this image binds bare SPC m f to this;
;;                        apheleia's `apheleia-indent-lisp-buffer' is
;;                        already Doom's default for scheme-mode, so this
;;                        is purely for cross-language muscle-memory
;;                        consistency, not filling a real gap)

;;; Code:

(after! scheme
  (map! :map scheme-mode-map
        :localleader
        :desc "Format buffer" "f" #'apheleia-format-buffer))

(provide 'guile-keybindings)
;;; guile-keybindings.el ends here
