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

  (defun +dape--first-executable (dir)
    "Return the first regular, executable file directly in DIR, or nil.
Pure directory scan, no build triggered -- shared by any `:program'
resolver that locates a build's already-built output by looking in a
known directory, rather than asking the build tool directly the way
`+dape-cargo-program' can (cargo has no analog for CMake/Zig's own
fixed build-output directory conventions)."
    (car (seq-filter (lambda (f) (and (file-regular-p f) (file-executable-p f)))
                      (directory-files dir t directory-files-no-dot-files-regexp))))

  (defun +dape-cmake-program ()
    "Path to the current CMake project's built executable, or nil.
Unlike cargo, cmake has no single-command way to ask \"what did you
build\" -- this just looks for the one executable file sitting directly
in ./build (this repo's convention, see +cmake--root). Doesn't trigger a
build; run `SPC m b b' first."
    (when-let* ((root (locate-dominating-file default-directory "CMakeLists.txt"))
                (build-dir (expand-file-name "build" root))
                ((file-directory-p build-dir)))
      (+dape--first-executable build-dir)))

  (defun +dape-zig-program ()
    "Path to the current Zig project's built executable, or nil.
Mirrors `+dape-cmake-program' above -- `zig build' has no single-command
way to ask what got built (the output name comes from `build.zig''s own
`b.addExecutable' call, not reliably derivable from the directory name),
so this just looks for the one executable file in zig-out/bin, `zig
build''s own fixed output location (confirmed live). Doesn't trigger a
build; run `SPC m b' first.
Falls back to the current buffer's own basename, sans extension, when no
build.zig exists anywhere up the tree -- confirmed live that a lone-file
`zig build-exe foo.zig' compile produces `./foo' in the current
directory, no zig-out/ involved at all. Gated on `zig-mode' specifically
(unlike the cargo/cmake fallbacks above, which are already marker-gated
and safely return nil on no match) -- otherwise this fallback would
return a bogus non-nil path for *any* buffer with no Cargo.toml/
CMakeLists.txt/build.zig anywhere up its tree, e.g. shadowing asm-mode's
own \"a.out\" fallback below with a wrong basename-derived guess instead."
    (if-let* ((root (locate-dominating-file default-directory "build.zig"))
              (bin-dir (expand-file-name "zig-out/bin" root))
              ((file-directory-p bin-dir)))
        (+dape--first-executable bin-dir)
      (when (and (derived-mode-p 'zig-mode) (buffer-file-name))
        (file-name-sans-extension (buffer-file-name)))))

  (defun +dape-resolve-program ()
    "Resolve the debug target binary for the current project.
Tries cargo, then CMake, then Zig; falls back to dape's own \"a.out\"
default for anything else (e.g. a bare `cc foo.c')."
    (or (+dape-cargo-program) (+dape-cmake-program) (+dape-zig-program) "a.out"))

  (dolist (name '(gdb lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setq config (plist-put config :program #'+dape-resolve-program))
      ;; dape's own built-in `gdb' config hardcodes `modes' to
      ;; (c-mode c-ts-mode c++-mode c++-ts-mode hare-mode hare-ts-mode) --
      ;; confirmed directly from dape.el's source -- asm-mode isn't in
      ;; that list at all, despite gdb being just as real a debugger for
      ;; hand-written assembly as it is for C (no separate adapter
      ;; needed; this is exactly the case ROADMAP.md's original Assembly
      ;; step meant by "no debugger integration needed beyond what gdb
      ;; already provides," but that claim needed this one line to
      ;; actually be true). No separate `:program' resolver needed --
      ;; `+dape-resolve-program' above already falls back to the literal
      ;; "a.out" default when neither a Cargo.toml nor a CMakeLists.txt
      ;; is found, the same convention a bare `as -g foo.s -o a.out'
      ;; assemble-and-link already matches. Only `gdb' gets this --
      ;; lldb-dap/lldb-vscode are this file's Rust-only adapters (see
      ;; DECISIONLOG.md), not used for assembly.
      (when (eq name 'gdb)
        (setq config (plist-put config 'modes (append (plist-get config 'modes) '(asm-mode)))))
      (setf (alist-get name dape-configs) config)))

  ;; Same gap class as gdb/asm-mode above: neither lldb adapter's built-in
  ;; `modes' list includes zig-mode. Zig debugging is an lldb job here,
  ;; not a gdb one -- matching Rust, not Assembly. This is its own dolist
  ;; over lldb-dap/lldb-vscode only rather than folded into the gdb dolist
  ;; above, the same shape as the :disableASLR/:stopOnEntry patches below
  ;; -- each independent lldb-dap/lldb-vscode-only concern in this file
  ;; gets its own loop rather than accumulating onto an unrelated one.
  (dolist (name '(lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setf (alist-get name dape-configs)
            (plist-put config 'modes (append (plist-get config 'modes) '(zig-mode))))))

  ;; dape's own default `command-cwd' (`dape-command-cwd' -> `project-current')
  ;; determines two things, not just one: it's both the adapter process's
  ;; own working directory AND -- via `dape--guess-root', called *before*
  ;; `:program' gets evaluated, to bind `default-directory' for that whole
  ;; evaluation -- what every function-valued config entry above sees too,
  ;; including `+dape-resolve-program' itself. Doom prepends
  ;; `project-projectile' ahead of project.el's own VC backend in
  ;; `project-find-functions', and neither
  ;; `projectile-project-root-files-bottom-up' nor project.el's own
  ;; `project-vc-extra-root-markers' (tried and confirmed to make no
  ;; difference -- `project-projectile' wins the race before project.el's
  ;; VC backend ever runs) know about `Cargo.toml'/`CMakeLists.txt'/
  ;; `go.mod'. Any project nested inside this repo's own git tree (every
  ;; flight-test fixture here, by construction) resolves to the outer git
  ;; root instead.
  ;;
  ;; This broke gdb/lldb-dap/lldb-vscode too, not just `dlv' -- it just
  ;; broke *quietly* there: `+dape-cargo-program'/`+dape-cmake-program's
  ;; own `locate-dominating-file' calls got silently poisoned by the wrong
  ;; `default-directory' and fell through to dape's literal "a.out"
  ;; default instead of erroring, so it went unnoticed until Rust's own
  ;; flight-test started failing with a Cargo.toml-not-found symptom on a
  ;; second look -- Go's `dlv' (no `:program' resolver of its own to mask
  ;; it, and delve's own `go build' error is loud) is what surfaced the
  ;; underlying bug first, but fixing only its `command-cwd' left the
  ;; other three configs exposed to the exact same root cause.
  ;;
  ;; Fix, same shape for all four: walk up for the real marker file
  ;; directly, bypassing project/projectile entirely rather than trying
  ;; to fix root detection globally, same as the `:program' resolvers.
  (defun +dape-resolve-cwd ()
    "Directory containing the nearest Cargo.toml, CMakeLists.txt, or build.zig.
Falls back to the current buffer's own directory for anything else
\(e.g. a bare assembly file with no project manifest at all) --
confirmed live that dape's own guess (`dape-command-cwd', the same
broken `project-current' chain documented above) resolves to \"//\"
when *no* marker file exists anywhere up the directory tree, not just
the wrong root: gdb then looks for the relative `:program' \"a.out\" at
`//a.out', finds nothing, and every breakpoint sits `pending' forever
with an entirely empty adapter output buffer -- silent, not an error.
Same fix shape as `+dape-lua-cwd' below, same reasoning: a file with no
project manifest to anchor on shouldn't route through project-root
guessing at all."
    (or (locate-dominating-file default-directory "Cargo.toml")
        (locate-dominating-file default-directory "CMakeLists.txt")
        (locate-dominating-file default-directory "build.zig")
        default-directory))

  (defun +dape-go-root ()
    "Directory containing the nearest go.mod, or dape's own guess as fallback."
    (or (locate-dominating-file default-directory "go.mod")
        (dape-command-cwd)))

  (dolist (name '(gdb lldb-dap lldb-vscode))
    (when-let* ((config (alist-get name dape-configs)))
      (setf (alist-get name dape-configs)
            (plist-put config 'command-cwd #'+dape-resolve-cwd))))

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
            (plist-put config :stopOnEntry t))))

  ;; dape has no built-in Lua config -- unlike gdb/lldb-dap/dlv/debugpy,
  ;; nothing here is patching an existing entry. `local-lua-debugger-vscode'
  ;; (tomblind) was picked over `actboy168/lua-debug' (more capable, but no
  ;; real prebuilt-binary distribution -- its GitHub Releases page has been
  ;; empty since 2019, and building it needs a custom `luamake' toolchain
  ;; and submodule deps, exactly the kind of fragile from-source build this
  ;; project avoids elsewhere) -- this one is pure TypeScript/Node with a
  ;; single runtime dependency (`vscode-debugadapter'), a normal, boring
  ;; `npm install && npm run build' (Dockerfile), no native compilation.
  ;;
  ;; Its debug adapter (`extension/debugAdapter.js') is a plain stdio DAP
  ;; server, same shape as gdb/lldb-dap -- launched directly via
  ;; `command'/`command-args', no socket/port needed. Two things it needs
  ;; that a normal VS Code install would supply automatically and silently:
  ;; - `:extensionPath': not derived by the adapter itself -- it's expected
  ;;   directly in the launch config (VS Code's extension host injects its
  ;;   own install dir before forwarding the config; going straight to
  ;;   debugAdapter.js like this bypasses that, so it has to be supplied by
  ;;   hand). Without it, `extensionPath' is literally the string
  ;;   "undefined" in the constructed require path -- confirmed live, the
  ;;   Lua-side `require('lldebugger')' fails with "no file
  ;;   'undefined/debugger/lldebugger.lua'".
  ;; - `:program' is a *nested* plist here (`:lua'/`:file'), not a bare
  ;;   string like every other config in this file -- this adapter's own
  ;;   launch schema, not a dape convention.
  ;;
  ;; `:file'/`:cwd' deliberately don't reuse `dape-buffer-default'/
  ;; `dape-cwd' (both ultimately root-cause back to the same broken
  ;; `project-current' chain fixed above for gdb/lldb-dap/dlv) or a
  ;; `+dape-resolve-cwd'-style marker-file walk -- a Lua script being
  ;; debugged here rarely has a project manifest to anchor a root search on
  ;; in the first place (this project's own Lua flight-test doesn't).
  ;; `buffer-file-name' is simpler and immune to the whole class of bug:
  ;; `current-buffer' is never rebound by `dape--guess-root', only
  ;; `default-directory' is, so an absolute path straight from the buffer
  ;; itself sidesteps the problem entirely rather than working around it.
  (defun +dape-lua-file ()
    "Absolute path to the current buffer's file."
    (buffer-file-name))

  (defun +dape-lua-cwd ()
    "Directory containing the current buffer's file."
    (file-name-directory (buffer-file-name)))

  (setf (alist-get 'lua-local dape-configs)
        (list 'modes '(lua-mode)
              'command "node"
              'command-args (list (expand-file-name "~/.local/lib/local-lua-debugger-vscode/extension/debugAdapter.js"))
              :type "lua-local"
              :request "launch"
              :program (list :lua "lua" :file #'+dape-lua-file)
              :cwd #'+dape-lua-cwd
              :extensionPath (expand-file-name "~/.local/lib/local-lua-debugger-vscode"))))

(provide 'dape-config)
;;; dape-config.el ends here
