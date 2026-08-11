(defun greet (name)
  (format nil "Hello from Common Lisp, ~a!" name))

(defun josiah-greet ()
  (greet "My name is Josiah!"))

(format t "~a~%" (josiah-greet))
(format t "~a~%" (greet "systems-ide"))
