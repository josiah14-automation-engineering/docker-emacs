(import (chezscheme))

(define (greet name)
  (string-append "Hello from Chez, " name "!"))

(define (josiah-greet)
  (greet "My name is Josiah!"))

(display (josiah-greet))
(newline)

(display (greet "systems-ide"))
(newline)
