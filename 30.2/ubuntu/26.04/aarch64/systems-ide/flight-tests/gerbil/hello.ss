(def (greet name)
  (string-append "Hello from Gerbil, " name "!"))

(def (hello msg)
  displayln msg)

(displayln (greet "systems-ide"))
