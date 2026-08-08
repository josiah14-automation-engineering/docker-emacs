;; Gambit Scheme flight test.

(define (greet name)
  (string-append "Hello from Gambit, " name "!"))

(display (greet "systems-ide"))
(newline)
