(define-module (utils)
  #:export (greet))

(define (greet name)
  (string-append "Hello from Guile, " name "!"))
