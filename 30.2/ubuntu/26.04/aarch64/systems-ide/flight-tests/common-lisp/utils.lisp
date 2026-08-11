(defpackage #:systems-ide-utils
  (:use #:cl)
  (:export #:utils-greet #:*utils-loaded*))

(in-package #:systems-ide-utils)

(defparameter *utils-loaded* t)

(defun utils-greet (name)
  (format nil "Hello from utils, ~a!" name))
