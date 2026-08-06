;;; gerbil-keybindings.el --- Gerbil Scheme mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Unlike Guile/Racket, gerbil-mode has no Doom :lang module, so none of
;; the usual localleader map exists for it. Upstream's own gerbil-mode.el
;; (see packages.el) instead binds its REPL/build commands directly on
;; gerbil-mode-map, unrelated to Doom's localleader/leader DSL:
;;   C-c C-f   compile current buffer (gxc)
;;   C-c C-i   import current buffer into the REPL
;;   C-c C-r   reload current buffer in the REPL
;;   C-c C-b   build the current project
;;   C-c C-e   eval current definition
;;   C-c C-c   eval current region
;;   C-x 9     restart the Scheme REPL process
;; gerbil-config.el wires the Doom-native equivalents for REPL toggling
;; and eval (SPC r/SPC c e etc., the same generic keys every other
;; language's REPL uses) on top of these -- nothing here duplicates that.
;;
;; LOCAL-LEADER -- this file's own bindings (SPC m ...):
;;   e b/B   reload buffer            e e   eval last sexp
;;   e d/D   eval definition          e r/R eval region
;;   f       format buffer   (apheleia-format-buffer -- every other language
;;                        in this image binds bare SPC m f to this;
;;                        apheleia's `apheleia-indent-lisp-buffer' is
;;                        already Doom's default for scheme-mode, and
;;                        gerbil-mode inherits that as a derived mode,
;;                        so this is purely for cross-language
;;                        muscle-memory consistency, matching guile-
;;                        keybindings.el's own reasoning).

;;; Code:

(after! gerbil-mode
  (map! :map gerbil-mode-map
        :localleader
        (:prefix ("e" . "eval")
         :desc "Eval buffer" "b" #'gerbil-reload-current-buffer
         :desc "Eval buffer and switch" "B" #'+gerbil-reload-current-buffer-and-go
         :desc "Eval last sexp" "e" #'scheme-send-last-sexp
         :desc "Eval definition" "d" #'scheme-send-definition
         :desc "Eval definition and switch" "D" #'scheme-send-definition-and-go
         :desc "Eval region" "r" #'scheme-send-region
         :desc "Eval region and switch" "R" #'scheme-send-region-and-go)
        :desc "Format buffer" "f" #'apheleia-format-buffer))

(provide 'gerbil-keybindings)
;;; gerbil-keybindings.el ends here
