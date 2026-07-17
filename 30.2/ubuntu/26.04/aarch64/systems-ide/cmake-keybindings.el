;;; cmake-keybindings.el --- CMake mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:

;; Default Doom/LSP bindings active in cmake-mode buffers (reference):
;;   g d         go to definition        (lsp / xref)
;;   K           hover documentation     (lsp)
;;   ] d / [ d   next / prev diagnostic  (flycheck)
;;   SPC b c     flycheck buffer         (config.el global)
;;
;; Doom's own :lang cc module already hooks `lsp!' onto cmake-mode's
;; local-vars-hook and sets up company-cmake -- nothing extra needed here
;; for that part.
;;
;; LOCAL-LEADER — this file's own bindings (SPC m ...):
;;   b c   configure       (+cmake/configure, via `cmake -B build -S .')
;;   b b   build           (+cmake/build, via `cmake --build build')
;;   b r   rebuild (clean) (+cmake/rebuild, via `cmake --build build --clean-first')
;;   b d   delete build/   (+cmake/clean, via `rm -rf build')
;;
;; All four run from the outermost CMakeLists.txt above the current buffer
;; (+cmake--root), not the buffer's own `default-directory' -- matters when
;; the buffer being edited is a nested subdirectory CMakeLists.txt (an
;; add_subdirectory() target), which isn't independently buildable.
;; Deliberately not `projectile-project-root': that resolves to the nearest
;; VCS root, which for a CMake project nested inside a larger monorepo (no
;; CMakeLists.txt of its own at the repo root -- e.g. this very project's
;; own flight-tests/c/) would point well above the actual project: wrong
;; directory for `cmake -B build`, and a much larger, wrong blast radius
;; for `rm -rf build'.

;;; Code:

(defun +cmake--root ()
  "Return the outermost ancestor directory containing a CMakeLists.txt.
Climbs past nested CMakeLists.txt files (e.g. add_subdirectory() targets)
to the top-level project directory. Falls back to `default-directory' if
none is found (shouldn't happen from a cmake-mode buffer)."
  (let ((root default-directory) (search-from default-directory) next)
    (while (setq next (locate-dominating-file search-from "CMakeLists.txt"))
      (setq root next
            search-from (expand-file-name ".." next)))
    root))

(defun +cmake/configure ()
  "Configure the current CMake project into ./build."
  (interactive)
  (let ((default-directory (+cmake--root)))
    (compile "cmake -B build -S .")))

(defun +cmake/build ()
  "Build the current CMake project from ./build."
  (interactive)
  (let ((default-directory (+cmake--root)))
    (compile "cmake --build build")))

(defun +cmake/rebuild ()
  "Force a clean rebuild of the current CMake project.
Runs the underlying build tool's clean target first (e.g. `make clean'),
so every source file recompiles regardless of stale timestamps -- unlike
`+cmake/build', which lets Make skip files it thinks are unchanged."
  (interactive)
  (let ((default-directory (+cmake--root)))
    (compile "cmake --build build --clean-first")))

(defun +cmake/clean ()
  "Delete the current CMake project's ./build directory entirely.
Unlike `+cmake/rebuild' (which only clears compiled objects via the
underlying build tool), this removes CMakeCache.txt and all generated
build files too -- run `+cmake/configure' again afterward."
  (interactive)
  (let ((default-directory (+cmake--root)))
    (compile "rm -rf build")))

(map! :map cmake-mode-map
      :localleader
      (:prefix ("b" . "build")
       :desc "Configure"       "c" #'+cmake/configure
       :desc "Build"           "b" #'+cmake/build
       :desc "Rebuild (clean)" "r" #'+cmake/rebuild
       :desc "Delete build/"   "d" #'+cmake/clean))

(provide 'cmake-keybindings)
;;; cmake-keybindings.el ends here
