;;; keybindings.el -*- lexical-binding: t; -*-

(map! :map metal-mercury-mode-map
      :localleader
      "c" #'metal-mercury-mode-compile
      "r" #'metal-mercury-mode-runner)
