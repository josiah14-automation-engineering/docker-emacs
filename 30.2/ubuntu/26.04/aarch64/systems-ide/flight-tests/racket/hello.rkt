#lang racket

(define (greet name)
  (string-append "Hello, " name "!"))

(displayln (greet "world"))
