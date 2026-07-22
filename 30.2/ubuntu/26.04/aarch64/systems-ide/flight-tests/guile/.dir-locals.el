;; Geiser's per-form/per-buffer evaluation sends form *text* straight to the
;; REPL rather than telling Guile to `load' the file -- Guile is never
;; actually reading through main.scm, so `(current-filename)' (which only
;; means something while a file is genuinely being read top to bottom) has
;; nothing to point to. `(add-to-load-path (dirname (current-filename)))'
;; silently does nothing useful under that evaluation style, even though it
;; works fine for a plain `guile main.scm' run (confirmed live: both were
;; tested directly). `default-directory' doesn't have this problem -- Emacs
;; always knows a buffer's own directory unambiguously, regardless of how
;; its contents get evaluated -- so this sets Geiser's load path here
;; directly instead of leaning on Guile's own file-reading context.
((scheme-mode . ((eval . (add-to-list 'geiser-guile-load-path default-directory)))))
