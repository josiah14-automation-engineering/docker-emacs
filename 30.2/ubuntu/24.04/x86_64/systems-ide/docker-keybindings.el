;;; docker-keybindings.el --- Docker/Podman engine toggle -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom bindings already active (from :tools docker, :config
;; default):
;;   SPC o D   open docker.el's tabulated container/image/volume UI
;;
;; docker.el (`M-x docker') always targets whichever binary `docker-command'
;; names -- "docker" by default. Both `docker' and `podman' clients are
;; installed in this image, each bridged to the host's real docker.service
;; and podman.socket respectively (see run.sh) rather than running either
;; engine's storage inside the container. `docker-command' only points at
;; one backend at a time; there's no built-in way to view both
;; simultaneously through the same UI.
;;
;; GLOBAL — this file's own binding (SPC o ...):
;;   o c   toggle docker.el's active backend between docker/podman

;;; Code:

(defun +docker/toggle-engine ()
  "Toggle `docker-command' between \"docker\" and \"podman\"."
  (interactive)
  (setq docker-command (if (equal docker-command "docker") "podman" "docker"))
  (message "docker.el now targets: %s" docker-command))

(map! :leader
      (:prefix "o"
       :desc "Toggle docker/podman engine" "c" #'+docker/toggle-engine))

(provide 'docker-keybindings)
;;; docker-keybindings.el ends here
