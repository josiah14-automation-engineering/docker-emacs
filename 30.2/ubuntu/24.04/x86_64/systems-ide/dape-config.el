;;; dape-config.el --- shared dape (debugger) configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Cross-language dape config -- not specific to any one `:lang' module.
;; `gdb'/`lldb-dap'/`lldb-vscode' are shared debug-adapter configs that
;; multiple languages route through (currently c/c++/rust; any future
;; DWARF-debuggable systems language, e.g. Zig, would hook in here too
;; rather than duplicating this per language).

;;; Code:

;; dape's built-in `gdb'/`lldb-dap'/`lldb-vscode' configs all hardcode
;; :program "a.out" -- a generic placeholder from C's `cc foo.c' default
;; output name, wrong for both cargo (target/debug/<bin>) and this repo's
;; CMake convention (build/<target>, see +cmake--root in
;; cmake-keybindings.el). lldb and gdb both require an actual compiled
;; binary path, so there's no shortcut -- it has to be resolved per-project.
;; dape evaluates function-valued config entries with no arguments and
;; substitutes the return value, so :program can point at a resolver
;; instead of a literal string.
(after! dape
  (defun +dape-cargo-program ()
    "Path to the current cargo project's build output, or nil.
Asks cargo directly via `--message-format=json' rather than guessing
target/debug/<crate-name> -- the crate name and the [[bin]] name can
differ, and this is what cargo itself reports as authoritative. Also
means invoking the debugger builds first, same as `SPC m b b'."
    (when-let* ((root (locate-dominating-file default-directory "Cargo.toml")))
      (with-temp-buffer
        (let ((default-directory root))
          (call-process "cargo" nil t nil "build" "--message-format=json"))
        (goto-char (point-min))
        (let (program)
          (while (re-search-forward "^{.*}$" nil t)
            (when-let* ((msg (ignore-errors (json-parse-string (match-string 0) :object-type 'alist)))
                        ((equal (alist-get 'reason msg) "compiler-artifact"))
                        (exe (alist-get 'executable msg)))
              (setq program exe)))
          program))))

  (defun +dape-cmake-program ()
    "Path to the current CMake project's built executable, or nil.
Unlike cargo, cmake has no single-command way to ask \"what did you
build\" -- this just looks for the one executable file sitting directly
in ./build (this repo's convention, see +cmake--root). Doesn't trigger a
build; run `SPC m b b' first."
    (when-let* ((root (locate-dominating-file default-directory "CMakeLists.txt"))
                (build-dir (expand-file-name "build" root))
                ((file-directory-p build-dir)))
      (car (seq-filter (lambda (f) (and (file-regular-p f) (file-executable-p f)))
                        (directory-files build-dir t directory-files-no-dot-files-regexp)))))

  (defun +dape-resolve-program ()
    "Resolve the debug target binary for the current project.
Tries cargo, then CMake; falls back to dape's own \"a.out\" default for
anything else (e.g. a bare `cc foo.c')."
    (or (+dape-cargo-program) (+dape-cmake-program) "a.out"))

  (dolist (name '(gdb lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setf (alist-get name dape-configs)
            (plist-put config :program #'+dape-resolve-program))))

  ;; dape's built-in `dlv' config launches delve with `:program "."'/
  ;; `:cwd "."' -- both resolved by delve itself relative to the *adapter
  ;; process's own* working directory, i.e. `command-cwd', which defaults
  ;; to `dape-command-cwd' -> `project-current'. Doom prepends
  ;; `project-projectile' ahead of project.el's own VC backend in
  ;; `project-find-functions', and `projectile-project-root-files-bottom-up'
  ;; has no `go.mod' entry -- so a Go module nested inside this repo's own
  ;; git tree (e.g. flight-tests/go/) resolves to the outer git root
  ;; instead, and `go build .' fails there with "cannot find main module".
  ;; Same class of bug as +cmake--root; same fix shape: walk up for the
  ;; real marker file directly instead of trusting project/projectile.
  (defun +dape-go-root ()
    "Directory containing the nearest go.mod, or dape's own guess as fallback."
    (or (locate-dominating-file default-directory "go.mod")
        (dape-command-cwd)))

  (when-let* ((config (alist-get 'dlv dape-configs)))
    (setf (alist-get 'dlv dape-configs)
          (plist-put config 'command-cwd #'+dape-go-root)))

  ;; lldb-dap's launch handler tries to disable ASLR via `personality()'
  ;; before running the debuggee, same as gdb -- but where gdb just warns
  ;; and proceeds when that syscall is denied (this container's default
  ;; seccomp profile denies it), lldb-dap treats it as a fatal launch
  ;; error. `:disableASLR' is lldb-dap's own DAP launch argument for this
  ;; (found via strace -- neither `~/.lldbinit' nor an `initCommands'
  ;; settings call reach it in time; this is handled before either runs).
  ;; Setting it false skips the syscall entirely, so no container
  ;; capability/seccomp change is needed at all. See DECISIONLOG.md.
  (dolist (name '(lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setf (alist-get name dape-configs)
            (plist-put config :disableASLR nil))))

  ;; dape sends `launch' unconditionally right after `initialize''s
  ;; response, in a separate, unsynchronized code path from
  ;; `setBreakpoints' (which only fires once the adapter sends its own
  ;; `initialized' event, whenever it decides it's ready). This is a real
  ;; race: if lldb-dap's `initialized' event arrives after dape's `launch'
  ;; has already taken effect, breakpoints land too late and the program
  ;; just runs to completion, ignored. dape's own `defer-launch-attach'
  ;; flag exists for exactly this ambiguity, but flipping it deadlocks
  ;; lldb-dap entirely here (`initialized' apparently never arrives if
  ;; `launch' hasn't already been sent -- a chicken-and-egg with this
  ;; adapter specifically). `:stopOnEntry' sidesteps the race instead of
  ;; fixing its timing: the process pauses at its very first instruction
  ;; regardless of breakpoints, giving the late `setBreakpoints' request
  ;; time to land before anything resumes. One extra `SPC d c' is needed
  ;; on every launch to get past that initial stop. See DECISIONLOG.md.
  (dolist (name '(lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setf (alist-get name dape-configs)
            (plist-put config :stopOnEntry t)))))

(provide 'dape-config)
;;; dape-config.el ends here
