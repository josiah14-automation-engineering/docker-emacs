;; Geiser evaluates form text rather than loading main.scm, so Guile's
;; current-filename cannot supply this project directory during evaluation.
((scheme-mode . ((eval . (add-to-list 'geiser-guile-load-path default-directory)))))
