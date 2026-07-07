;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;; (package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;; (package! another-package
;;   :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;; (package! builtin-package :recipe (:nonrecursive t))
;; (package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;; (package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;; (package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;; (unpin! pinned-package)
;; ...or multiple packages
;; (unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;; (unpin! t)

(package! flycheck-mercury)
(package! metal-mercury-mode
  :recipe (:host github :repo "ahungry/metal-mercury-mode"))

;; sweeprolog is distributed via NonGNU ELPA, not MELPA, and its package
;; name differs from its "sweep" project nickname -- both confirmed by
;; cloning github.com/SWI-Prolog/packages-sweep directly (the actual repo;
;; github.com/eshelyaron/sweep, an earlier guess, 404s). `:files' explicitly
;; adds sweep.pl alongside straight's default *.el matching: the package's
;; own `sweeprolog--ensure-module' loads "sweep.pl" from
;; `sweeprolog--directory' (the straight checkout dir itself, per
;; `(defvar sweeprolog--directory (file-name-directory load-file-name))'),
;; and straight's default :files spec only picks up *.el/*.info/etc, so
;; without this the package would fail at runtime with "Missing file
;; `sweep.pl' in `sweeprolog' directory" despite installing cleanly.
(package! sweeprolog
  :recipe (:host github :repo "SWI-Prolog/packages-sweep"
           :files (:defaults "sweep.pl")))

