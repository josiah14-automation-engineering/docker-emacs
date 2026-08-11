(load (merge-pathnames "utils.lisp" *load-truename*))
(use-package :systems-ide-utils)

(defun greet (name)
  (format nil "Hello from Common Lisp, ~a!" name))

(defun josiah-greet ()
  (let ((message "My name is Josiah!")
        (count 0))
    (setq message (greet message))
    (setf count 2)
    (incf count)
    (decf count)
    message))

(format t "~a~%" (josiah-greet))
(format t "~a~%" (greet "systems-ide"))
