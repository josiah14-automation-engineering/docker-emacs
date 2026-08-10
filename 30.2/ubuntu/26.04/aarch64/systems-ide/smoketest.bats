#!/usr/bin/env bats

# IDE smoketest for systems-ide (Shell + Go + Rust + Nix + Guile + Racket +
# Rash + Bats + Nushell + C/C++/CMake + Lua + Python/Ruby/JavaScript/
# TypeScript glue-script tier + Fish + Assembly + Zig + TOML + Perl/Haskell
# syntax-only).
#
# Verifies the actual Doom Emacs session boots correctly and each implemented
# language's major mode, checkers, LSP wiring, and keybindings resolve as
# configured -- not just that packages installed without error at build time.
#
# IMPORTANT: must run against a real (non-batch) Emacs daemon, not
# `emacs --batch` -- see logic-ide/smoketest.bats for the confirmed reason
# (Doom skips doom-font and module config entirely under `noninteractive').
#
# Run via: bats smoketest.bats
# bash-language-server, shellcheck, zshdb, go, gopls, dlv, golangci-lint, bats,
# nu, guile, racket, racket-langserver, rash, raco fmt, clang(d), gcc/g++, cmake, gdb, cmake-language-server, vcpkg, conan, lua,
# lua-language-server, stylua, python3, pyright, ruff, ruby, ruby-lsp,
# rubocop, typescript-language-server, prettier, oxlint, cargo, rustc,
# rust-analyzer, rustfmt, clippy, lldb, fish, fish-lsp, asm-lsp, zig, zls,
# taplo are all baked into the image at build time (no network/host bind
# mounts required). nu and
# clangd both double as their own LSP server, no separate language-server
# package needed for either. ccls is deliberately not installed (see
# Dockerfile) -- Doom's own :lang cc module already deprioritizes it below
# clangd. eslint and solargraph are likewise deliberately not installed --
# oxlint and ruby-lsp are this project's chosen tools for those roles (see
# javascript-keybindings.el/ruby-keybindings.el). The nix CLI itself is
# checked separately in nix-smoketest.bats, since it depends on host bind
# mounts (see
# run.sh) not present here.

setup_file() {
  mkdir -p /tmp/smoketest
  cp -a "$(dirname "$BATS_TEST_FILENAME")/flight-tests" /tmp/flight-tests
  cat > /tmp/smoketest/test.bash <<'EOF'
#!/bin/bash
items=(wrong BASH_OK)
printf '%s\n' "${items[1]}"
greet() { echo hi; }
EOF
  cat > /tmp/smoketest/test.sh <<'EOF'
#!/bin/sh
value=SH_OK
printf '%s\n' "$value"
greet() { echo hi; }
EOF
  cat > /tmp/smoketest/test-shebang.sh <<'EOF'
#!/usr/bin/env bash
echo hi
EOF
  cat > /tmp/smoketest/test.lua <<'EOF'
print("hi")
EOF
  cat > /tmp/smoketest/test.py <<'EOF'
print("hi")
EOF
  cat > /tmp/smoketest/test-python-format.py <<'EOF'
def greet():
    return 'hi'
EOF
  cat > /tmp/smoketest/test-python-lint.py <<'EOF'
import os

print(undefined_name)
EOF
  cat > /tmp/smoketest/test.rb <<'EOF'
puts "hi"
EOF
  cat > /tmp/smoketest/test.js <<'EOF'
console.log("hi");
EOF
  cat > /tmp/smoketest/test.ts <<'EOF'
const message: string = "hi";
console.log(message);
EOF
  cat > /tmp/smoketest/test.zsh <<'EOF'
#!/bin/zsh
items=(wrong ZSH_OK)
printf '%s\n' "${items[2]}"
greet() { echo hi; }
EOF
  cat > /tmp/smoketest/test.ksh <<'EOF'
#!/bin/ksh
typeset -A values=([result]=KSH_OK)
printf '%s\n' "${values[result]}"
greet() { echo hi; }
EOF
  cat > /tmp/smoketest/test.go <<'EOF'
package main

func answer() int { return 42 }

func main() { _ = answer() }
EOF
  cat > /tmp/smoketest/test.rs <<'EOF'
fn main() {
    println!("hi");
}
EOF
  cat > /tmp/smoketest/test.nix <<'EOF'
{ answer = 42; }
EOF
  cat > /tmp/smoketest/test.nu <<'EOF'
def main [] {
  echo "hi"
}
EOF
  cat > /tmp/smoketest/test.scm <<'EOF'
;; -*- geiser-scheme-implementation: guile -*-
(display "hi")
(newline)
EOF
  cat > /tmp/smoketest/test-chez-auto.scm <<'EOF'
;; Example Chez Scheme program
(import (chezscheme))
(display "hi")
(newline)
EOF
  cat > /tmp/smoketest/test-chez-extension.def <<'EOF'
(define answer 42)
EOF
  cat > /tmp/smoketest/test-chez-content.ss <<'EOF'
(import (chezscheme))
(define answer 42)
EOF
  cat > /tmp/smoketest/test-gerbil-content.ss <<'EOF'
(def answer 42)
EOF
  cat > /tmp/smoketest/test-ambiguous.ss <<'EOF'
(define answer 42)
EOF
  cat > /tmp/smoketest/test-gambit-auto.scm <<'EOF'
;; Example Gambit Scheme program (gsi)
(display "hi")
(newline)
EOF
  cat > /tmp/smoketest/test-guile-auto.scm <<'EOF'
#!/usr/bin/env guile
!#
(display "hi")
(newline)
EOF
  cat > /tmp/smoketest/test.el <<'EOF'
(defun smoketest-greeting ()
  (message "hi"))
EOF
  cat > /tmp/smoketest/test.rkt <<'EOF'
#lang racket
(displayln "hi")
EOF
  cat > /tmp/smoketest/test-fmt.rkt <<'EOF'
#lang racket
(displayln
  "hi")
EOF
  cat > /tmp/smoketest/test-rash.rkt <<'EOF'
#lang rash
(displayln "hi")
EOF
  cat > /tmp/smoketest/test.ss <<'EOF'
(def (greet name) (displayln name))
EOF
  cat > /tmp/smoketest/test.c <<'EOF'
int main(void) {
    volatile int value = 42;
    return value == 42 ? 0 : 1;
}
EOF
  cat > /tmp/smoketest/test.cpp <<'EOF'
int main() { return 0; }
EOF
  # Deliberately NOT named test.h -- confirmed live that c-or-c++-mode's
  # ambiguous-header heuristic disambiguates via a same-basename sibling
  # source file when one exists (test.c/test.cpp both exist in this same
  # directory), landing on c++-mode instead of the "no sibling, no
  # content signal" fallback this test means to check. A unique basename
  # keeps this test's actual claim (Doom's default header fallback)
  # true regardless of what other fixtures share this directory.
  cat > /tmp/smoketest/header-only.h <<'EOF'
#pragma once
EOF
  cat > /tmp/smoketest/test.mm <<'EOF'
int main() { return 0; }
EOF
  cat > /tmp/smoketest/test.fish <<'EOF'
function greet
  echo "hi"
end
greet
EOF
  cat > /tmp/smoketest/test.pl <<'EOF'
print "hi\n";
EOF
  # Haskell deliberately stays syntax-only (see DECISIONLOG.md) -- an
  # XMonad-config-shaped snippet rather than a generic "hi" print, since
  # XMonad configs are this feature's actual motivating use case (Turtle
  # scripts are the other one, weighted slightly less -- see DECISIONLOG.md).
  # It won't compile (no xmonad package installed, syntax-only means no
  # type-checking is expected either), just needs to be valid enough
  # Haskell syntax for haskell-mode's font-lock/indentation to engage.
  cat > /tmp/smoketest/test.hs <<'EOF'
import XMonad
import XMonad.Util.EZConfig (additionalKeys)

main :: IO ()
main = xmonad $ def
  { terminal = "alacritty"
  , modMask = mod4Mask
  } `additionalKeys`
  [ ((mod4Mask, xK_p), spawn "dmenu_run")
  ]
EOF
  cat > /tmp/smoketest/test.zig <<'EOF'
const std = @import("std");

pub fn main() void {
    std.debug.print("hi\n", .{});
}
EOF
  cat > /tmp/smoketest/test-fmt.zig <<'EOF'
const std = @import("std");

pub fn main() void {
    std.debug.print(
        "hi\n"
    );
}
EOF
  cat > /tmp/smoketest/test.toml <<'EOF'
[package]
name = "smoketest"
version = "0.1.0"
EOF
  # In its own subdirectory, not /tmp/smoketest/ directly -- confirmed
  # live that go-mode.el registers a magic-mode-alist predicate
  # (go--is-go-asm) that activates go-asm-mode instead of plain
  # asm-mode whenever a .s file's own directory contains any .go file
  # (it's trying to detect Go's own runtime-assembly convention, where
  # .s files sit alongside .go sources in the same package directory).
  # /tmp/smoketest/test.go (this same setup_file, above) triggered
  # exactly that, silently swapping the major-mode out from under this
  # fixture -- same class of bug as header-only.h's sibling-file
  # collision, different mechanism (directory contents vs. same
  # basename).
  mkdir -p /tmp/smoketest/asm
  cat > /tmp/smoketest/asm/test.s <<'EOF'
.global main
main:
    mov w0, #42
    mov w1, w0
    ret
EOF
  # Separate top-level root, not just a subdirectory of /tmp/smoketest/ --
  # confirmed live that a subdirectory alone isn't isolation enough here:
  # locate-dominating-file walks *every* ancestor, and /tmp/smoketest/'s own
  # CMakeLists.txt fixture (below) is one, so +dape-resolve-cwd's "zero
  # markers anywhere" case can never actually be exercised by any file
  # nested under /tmp/smoketest/, no matter how deep -- the exact same class
  # of cross-fixture collision as the go-asm-mode bug above, just via
  # ancestor-directory search instead of same-directory sibling contents.
  mkdir -p /tmp/smoketest-nomarkers
  cat > /tmp/smoketest-nomarkers/test.s <<'EOF'
.global main
main:
    mov w0, #42
    mov w1, w0
    ret
EOF
  cat > /tmp/smoketest/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.10)
project(smoketest)
EOF
  # Nested add_subdirectory()-shaped target under the top-level project above --
  # exercises +cmake--root's climb-past-nested-CMakeLists.txt behavior, not just
  # the plain single-CMakeLists.txt case the fixture above already covers.
  mkdir -p /tmp/smoketest/nested-cmake
  cat > /tmp/smoketest/nested-cmake/CMakeLists.txt <<'EOF'
add_subdirectory(.)
EOF
  cat > /tmp/smoketest/test.bats <<'EOF'
#!/usr/bin/env bats

@test "addition works" {
  result="$(( 2 + 2 ))"
  [ "$result" -eq 4 ]
}
EOF
  gcc -g -O0 /tmp/smoketest/test.c -o /tmp/smoketest/test-c-debug
  start_emacs_daemon
}

start_emacs_daemon() {
  emacs --daemon > /tmp/smoketest/daemon.log 2>&1 &
  for _ in $(seq 1 60); do
    emacsclient --eval 1 >/dev/null 2>&1 && return
    sleep 1
  done
  echo "Emacs daemon never became ready" >&2
  cat /tmp/smoketest/daemon.log >&2
  return 1
}

teardown_file() {
  timeout 5 emacsclient --eval '(kill-emacs)' >/dev/null 2>&1 || true
  pkill -TERM emacs >/dev/null 2>&1 || true
}

eval_elisp() {
  emacsclient --eval "$1"
}

lsp_servers_for() {
  eval_elisp "(progn
    (find-file \"$1\")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar #'lsp--workspace-server-id (lsp-workspaces)))"
}

lsp_protocol_request_for() {
  eval_elisp "(progn
    (find-file \"$1\")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (let ((servers (mapcar #'lsp--workspace-server-id (lsp-workspaces))))
      (condition-case error
          (let ((response
                 (lsp-request
                  \"$2\"
                  (if (string= \"$2\" \"textDocument/documentSymbol\")
                      (list :textDocument (lsp--text-document-identifier))
                    (lsp--text-document-position-params)))))
            (list servers (not (null response))))
        (error (list servers nil (error-message-string error))))))"
}

lsp_result_for() {
  eval_elisp "(progn
    (find-file \"$1\")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline)
                  (not (lsp--capability-for-method \"$2\")))
        (sleep-for 0.2)))
    (sleep-for 1)
    (goto-char (point-max))
    (unless (string= \"$3\" \"-\") (search-backward \"$3\"))
    (let (response last-error)
      (dotimes (_ 5)
        (unless response
          (condition-case error
              (setq response
                    (lsp-request
                     \"$2\"
                     (if (string= \"$2\" \"textDocument/documentSymbol\")
                         (list :textDocument (lsp--text-document-identifier))
                       (lsp--text-document-position-params))))
            (error (setq last-error error) (sleep-for 1)))))
      (if response
          (list (mapcar #'lsp--workspace-server-id (lsp-workspaces)) response)
        (signal (car last-error) (cdr last-error)))))"
}

dape_launch_for() {
  eval_elisp "(progn
    (require 'dape)
    (dolist (connection (copy-sequence dape--connections))
      (when (jsonrpc-running-p connection) (dape--shutdown connection)))
    (setq dape--connections nil)
    (find-file \"$1\")
    (dape-breakpoint-remove-all)
    (goto-char (point-min))
    (search-forward \"$5\")
    (beginning-of-line)
    (let ((target-line (line-number-at-pos))
          (source-buffer (current-buffer)))
      (when (or (not (memq '$2 '(gdb lldb-dap lldb-vscode)))
                (string-empty-p \"$7\"))
        (dape-breakpoint-toggle))
    (let ((options (list 'command-cwd \"$4\")))
      (when (eq '$2 'gdb)
        (setq options (plist-put options :stopAtBeginningOfMainSubprogram t)))
      (when (memq '$2 '(lldb-dap lldb-vscode))
        (setq options (plist-put options :stopOnEntry t)))
      (unless (string-empty-p \"$3\")
        (setq options (plist-put options :program \"$3\")))
      (dape (dape--config-eval '$2 options)))
    (let ((deadline (+ (float-time) 40)) conn frame result error)
      (while (and (< (float-time) deadline)
                  (not (setq conn (dape--live-connection 'stopped t))))
        (sleep-for 0.2))
      (when (and conn (memq '$2 '(gdb lldb-dap lldb-vscode)))
        (if (not (string-empty-p \"$7\"))
          (progn
          (let ((dape--request-blocking t))
            (dape-breakpoint-function \"$7\"))
          (unless (plist-get (dape--breakpoint-verified (car dape--breakpoints)) conn)
            (error \"Function breakpoint was not verified\"))
          (dape-continue conn)
          (setq deadline (+ (float-time) 20))
          (while (and (< (float-time) deadline)
                      (eq (dape--state conn) 'stopped))
            (sleep-for 0.1))
          (while (and (< (float-time) deadline)
                      (not (eq (dape--state conn) 'stopped)))
            (sleep-for 0.1))
          (dotimes (_ (string-to-number \"$8\"))
            (dape-next conn)
            (setq deadline (+ (float-time) 20))
            (sleep-for 0.2)
            (while (and (< (float-time) deadline)
                        (not (eq (dape--state conn) 'stopped)))
              (sleep-for 0.1))))
          (let ((breakpoint (with-current-buffer source-buffer
                              (car (dape--breakpoints-at-point)))))
            (unless breakpoint
              (error \"Source breakpoint was not created\"))
            (setq deadline (+ (float-time) 20))
            (while (and (< (float-time) deadline)
                        (not (plist-get (dape--breakpoint-verified breakpoint) conn)))
              (sleep-for 0.1)))
          (dape-continue conn)
          (setq deadline (+ (float-time) 20))
          (while (and (< (float-time) deadline)
                      (eq (dape--state conn) 'stopped))
            (sleep-for 0.1))
          (while (and (< (float-time) deadline)
                      (not (eq (dape--state conn) 'stopped)))
            (sleep-for 0.1))))
      (when conn
        (let (thread-id request-error)
          (let ((dape--request-blocking t))
            (dape--update-threads
             conn (lambda (_result error) (setq request-error error))))
          (setq thread-id
                (or (dape--thread-id conn)
                    (plist-get (car (dape--threads conn)) :id)))
          (when thread-id
            (let ((dape--request-blocking t))
              (dape-request
               conn :stackTrace (list :threadId thread-id :startFrame 0 :levels 1)
               (lambda (body callback-error)
                 (setq request-error callback-error
                       frame (car (append (plist-get body :stackFrames) nil))))))
            (setq error request-error))))
      (when frame
        (let ((dape--request-blocking t))
          (dape--evaluate-expression
           conn (plist-get frame :id) \"$6\" \"watch\"
           (lambda (body request-error)
             (setq result (plist-get body :result)
                   error request-error)))))
      (let* ((session (or conn (car dape--connections)))
             (state (and session (dape--state session)))
             (reason (and session (dape--state-reason session))))
        (when session (dape--shutdown session))
        (list (and frame
                   (if (string-empty-p \"$7\")
                       (= target-line (plist-get frame :line))
                     (and (string= (plist-get frame :name) \"$7\")
                          (> (plist-get frame :line) 0))))
              (plist-get frame :name) result error state reason)))))"
}

completion_contains_for() {
  eval_elisp "(progn
    (find-file \"$1\")
    (when (not (string-empty-p \"$2\"))
      (save-window-excursion
        (geiser-repl-switch nil (intern \"$2\") (current-buffer))))
    (goto-char (point-max))
    (insert \"\n($3\")
    (let ((capf (catch 'found
                  (dolist (fn completion-at-point-functions)
                    (when (functionp fn)
                      (let ((result (funcall fn)))
                        (when result (throw 'found result))))))))
      (and capf
           (not (null
                 (member \"$4\"
                         (all-completions
                          (buffer-substring-no-properties (nth 0 capf) (nth 1 capf))
                          (nth 2 capf))))))))"
}

@test "bash-language-server is installed and reports a version" {
  run bash-language-server --version
  [ "$status" -eq 0 ]
}

@test "shellcheck is installed and reports a version" {
  run shellcheck --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ShellCheck" ]]
}

@test "zshdb is installed" {
  run command -v zshdb
  [ "$status" -eq 0 ]
}

@test "RealGUD/zshdb hits a source breakpoint and evaluates a variable" {
  run eval_elisp '(progn
    (realgud:zshdb "zshdb /tmp/flight-tests/zsh/debug.zsh")
    (let ((deadline (+ (float-time) 20)) process buffer)
      (while (and (< (float-time) deadline)
                  (not (setq process
                             (seq-find
                              (lambda (candidate)
                                (member "zshdb" (process-command candidate)))
                              (process-list)))))
        (sleep-for 0.2))
      (setq buffer (and process (process-buffer process)))
      (while (and process (< (float-time) deadline)
                  (not (with-current-buffer buffer
                         (string-match-p "zshdb<0>" (buffer-string)))))
        (accept-process-output process 0.2))
      (process-send-string process "break 3\n")
      (process-send-string process "continue\n")
      (process-send-string process "print $debug_value\n")
      (while (and (< (float-time) deadline)
                  (not (with-current-buffer buffer
                         (string-match-p "zshdb<3>" (buffer-string)))))
        (accept-process-output process 0.2))
      (prog1
          (with-current-buffer buffer
            (list (bound-and-true-p zshdb-track-mode)
                  (string-match-p "Breakpoint 1 hit" (buffer-string))
                  (string-match-p "debug.zsh:3" (buffer-string))
                  (string-match-p "42\r?\n" (buffer-string))))
        (when (process-live-p process) (delete-process process)))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^\(t\ [0-9]+\ [0-9]+\ [0-9]+\)$ ]]
}

@test "sh, bash, zsh, and ksh interpreters are installed" {
  for shell in sh bash zsh ksh; do
    run command -v "$shell"
    [ "$status" -eq 0 ]
  done
}

@test "go is installed and reports the pinned version (1.26.3)" {
  run go version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "go1.26.3" ]]
}

@test "gopls is installed and reports the pinned version (v0.22.0)" {
  run gopls version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "v0.22.0" ]]
}

@test "Doom's environment exposes final-stage toolchains" {
  run eval_elisp '(mapcar (lambda (program) (cons program (executable-find program)))
                          (quote ("go" "gopls" "scheme" "gsi" "cargo" "racket" "zig")))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ " nil)" ]]
}

@test "dlv is installed and reports the pinned version (1.26.3)" {
  run dlv version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.26.3" ]]
}

@test "golangci-lint is installed and reports the pinned version (2.11.4)" {
  run golangci-lint --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.11.4" ]]
}

@test "bats is installed and reports a version" {
  run bats --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Bats" ]]
}

@test "nu is installed and reports the pinned version (0.114.1)" {
  run nu --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.114.1" ]]
}

@test "clang and clangd are installed" {
  run clang --version
  [ "$status" -eq 0 ]
  run clangd --version
  [ "$status" -eq 0 ]
}

@test "gcc and g++ are installed" {
  run gcc --version
  [ "$status" -eq 0 ]
  run g++ --version
  [ "$status" -eq 0 ]
}

@test "cmake and gdb are installed" {
  run cmake --version
  [ "$status" -eq 0 ]
  run gdb --version
  [ "$status" -eq 0 ]
}

@test "gdb version satisfies dape's built-in DAP requirement (>= 14.1)" {
  run bash -c "gdb --version | head -1 | grep -oE '[0-9]+' | head -1"
  [ "$status" -eq 0 ]
  [ "$output" -ge 14 ]
}

@test "cmake-language-server is installed and reports the pinned version (0.1.11)" {
  run cmake-language-server --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.1.11" ]]
}

@test "vcpkg is installed and runs" {
  # `vcpkg version` self-reports vcpkg-tool's own build date (e.g.
  # 2026-05-27-<sha>), NOT the VCPKG_VERSION tag this project actually
  # pins (2026.06.24) -- those are two independent versioning
  # schemes (the tool binary vs. the ports registry git tag), confirmed
  # live to genuinely differ. bootstrap-vcpkg.sh always fetches whatever
  # vcpkg-tool release is current, which this Dockerfile doesn't pin at
  # all, so asserting a specific tool-binary version here was never
  # actually testing something this project controls -- check that it
  # runs and self-identifies instead.
  run vcpkg version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "vcpkg package management program version" ]]
}

@test "conan is installed and reports the pinned version (2.30.0)" {
  run conan --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.30.0" ]]
}

@test "docker and podman clients are installed" {
  run docker --version
  [ "$status" -eq 0 ]
  run podman --version
  [ "$status" -eq 0 ]
}

@test "lua, lua-language-server, and stylua are installed" {
  run lua -v
  [ "$status" -eq 0 ]
  run "${HOME}/.local/lib/lua-language-server/bin/lua-language-server" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3.18.2" ]]
  run stylua --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.5.2" ]]
}

@test "python3, pyright, and ruff are installed" {
  run python3 --version
  [ "$status" -eq 0 ]
  run pyright --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.1.411" ]]
  run ruff --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.15.22" ]]
}

@test "ruby, ruby-lsp, and rubocop are installed" {
  run ruby --version
  [ "$status" -eq 0 ]
  run ruby-lsp --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.24.1" ]]
  run rubocop --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.88.2" ]]
}

@test "typescript-language-server, prettier, and oxlint are installed" {
  run typescript-language-server --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "5.3.0" ]]
  run prettier --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3.9.5" ]]
  run oxlint --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.74.0" ]]
}

@test "cargo, rust-analyzer, rustfmt, and clippy are installed" {
  run cargo --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.97.1" ]]
  run rust-analyzer --version
  [ "$status" -eq 0 ]
  run rustfmt --version
  [ "$status" -eq 0 ]
  run cargo-clippy --version
  [ "$status" -eq 0 ]
  run lldb-dap --version
  [ "$status" -eq 0 ]
}

@test "fish, fish-lsp, and asm-lsp are installed" {
  run fish --version
  [ "$status" -eq 0 ]
  run fish-lsp --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.1.4" ]]
  # asm-lsp is a clap subcommand CLI with no top-level --version flag
  # (confirmed live: `asm-lsp --version` errors "unexpected argument");
  # `asm-lsp version` is its own dedicated subcommand for this.
  run asm-lsp version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.10.1" ]]
}

@test "zig and zls are installed and report the pinned version (0.16.0)" {
  run zig version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.16.0" ]]
  run zls --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.16.0" ]]
}

@test "taplo is installed and reports the pinned version (0.10.0)" {
  run taplo --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0.10.0" ]]
}

@test "opening a .bash file activates sh-mode with the bash dialect" {
  # sh-mode is the only major mode for shell scripts; bash vs zsh is tracked
  # by the buffer-local sh-shell variable, not a separate major mode (this is
  # also why sh-keybindings.el binds sh-set-shell as "switch shell dialect").
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (format "%s %s" major-mode sh-shell))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sh-mode" ]]
  [[ "$output" =~ "bash" ]]
}

@test "sh-shell-file matches the shebang-detected dialect (shell-config.el's +shell--sync-shell-file)" {
  # Regression test: sh-set-shell's automatic (non-interactive) dialect
  # detection never used to update sh-shell-file, leaving it at the global
  # default (dash) regardless of sh-shell -- silently breaking
  # sh-execute-region (SPC m e e / SPC m e b) on any bash-only syntax for a
  # plain .sh file that only carries a #!/usr/bin/env bash shebang (no
  # .bash extension to trigger this project's own Bash selector instead).
  run eval_elisp '(progn (find-file "/tmp/smoketest/test-shebang.sh") (format "%s %s" sh-shell sh-shell-file))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "bash bash" ]]
}

@test "opening a .zsh file activates sh-mode with the zsh dialect" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.zsh") (format "%s %s" major-mode sh-shell))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sh-mode" ]]
  [[ "$output" =~ "zsh" ]]
}

@test "POSIX sh, Bash, Zsh, and Ksh execute through their detected interpreters" {
  while read -r file dialect interpreter expected; do
    run eval_elisp "(progn
      (find-file \"/tmp/smoketest/$file\")
      (when (get-buffer \"*Shell Command Output*\")
        (kill-buffer \"*Shell Command Output*\"))
      (sh-execute-region (point-min) (point-max))
      (list sh-shell sh-shell-file
            (with-current-buffer \"*Shell Command Output*\"
              (string-trim (buffer-string)))))"
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" == "($dialect \"$interpreter\" \"$expected\")" ]]
  done <<'EOF'
test.sh sh sh SH_OK
test.bash bash bash BASH_OK
test.zsh zsh zsh ZSH_OK
test.ksh pdksh ksh KSH_OK
EOF
}

@test "BashLS returns real symbols for supported POSIX sh and Bash buffers" {
  for file in test.sh test.bash; do
    run lsp_result_for "/tmp/smoketest/$file" textDocument/documentSymbol -
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bash-ls" ]]
    [[ "$output" =~ "greet" ]]
  done
}

# featurep, not bound-and-true-p: (lsp-deferred) is an autoloaded stub, so
# calling it from the mode hook forces lsp-mode.el to load synchronously even
# though the actual server handshake is scheduled for the next idle moment.
# Asserting the minor mode is ON here would race that handshake.
@test "bash-ls connects when a shell buffer is opened ((sh +lsp))" {
  run lsp_servers_for /tmp/smoketest/test.bash
  [ "$status" -eq 0 ]
  [[ "$output" =~ "bash-ls" ]]
}

@test "opening Zsh and Ksh does not attempt an unsupported LSP server" {
  run eval_elisp '(let (results)
    (dolist (file (quote ("/tmp/flight-tests/zsh/debug.zsh"
                          "/tmp/smoketest/test.ksh")))
      (when-let ((buffer (get-file-buffer file))) (kill-buffer buffer))
      (let (messages)
        (cl-letf (((symbol-function (quote message))
                   (lambda (format-string &rest args)
                     (push (apply (function format) format-string args) messages))))
          (find-file file)
          (sleep-for 1))
        (push (list sh-shell
                    (bound-and-true-p lsp-mode)
                    (and (seq-some
                          (lambda (text)
                            (string-match-p "no language server" (downcase text)))
                          messages)
                         t))
              results)))
    (nreverse results))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '((zsh nil nil) (pdksh nil nil))' ]]
}

@test "opening a .go file activates go-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.go") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "go-mode" ]]
}

@test "gopls connects and flycheck is active in go buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.go")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (list (mapcar (function lsp--workspace-server-id) (lsp-workspaces))
          (bound-and-true-p flycheck-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "gopls" ]]
  [[ "$output" =~ "t)" ]]
}

@test "gopls resolves a real definition request" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.go")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline)
                  (not (lsp--capability-for-method "textDocument/definition")))
        (sleep-for 0.2)))
    (goto-char (point-min))
    (search-forward "answer()" nil nil 2)
    (backward-char 3)
    (lsp-request "textDocument/definition" (lsp--text-document-position-params)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test.go" ]]
}

@test "opening a .rs file activates rustic-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rs") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "rustic-mode" ]]
}

@test "rust-analyzer connects for rustic-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.rs")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "rust-analyzer" ]]
}

@test "opening a .nix file activates nix-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nix") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "nix-mode" ]]
}

@test "opening a .bats file activates bats-mode with the bash dialect" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bats") (format "%s %s" major-mode sh-shell))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "bats-mode" ]]
  [[ "$output" =~ "bash" ]]
}

@test "Cucumber feature files activate functional Gherkin editing support" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/cucumber/editor.feature")
    (font-lock-ensure)
    (goto-char (point-min))
    (re-search-forward "^Feature:")
    (let ((feature-face (get-text-property (match-beginning 0) (quote face))))
      (search-forward "Then")
      (beginning-of-line)
      (delete-horizontal-space)
      (indent-according-to-mode)
      (list major-mode
            (substring-no-properties (feature-detect-language))
            (current-indentation)
            (and feature-face t)
            (mapcar (function commandp)
                    (list (key-binding (kbd "C-c ,s"))
                          (key-binding (kbd "C-c ,v"))
                          (key-binding (kbd "C-c ,f"))
                          (key-binding (kbd "C-c ,g")))))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '(feature-mode "en" 4 t (t t t t))' ]]
}

@test "bash-ls connects for bats-mode buffers" {
  run lsp_servers_for /tmp/smoketest/test.bats
  [ "$status" -eq 0 ]
  [[ "$output" =~ "bash-ls" ]]
}

@test "opening a .nu file activates nushell-ts-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nu") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "nushell-ts-mode" ]]
}

@test "nushell-ls connects when a nushell buffer is opened" {
  run lsp_servers_for /tmp/smoketest/test.nu
  [ "$status" -eq 0 ]
  [[ "$output" =~ "nushell-ls" ]]
}

@test "guile is installed and reports a version" {
  run guile --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Guile" ]]
}

@test "a cold first Scheme open autodetects each flight project from contents" {
  run eval_elisp '(mapcar
    (lambda (file)
      (with-current-buffer (find-file-noselect file)
        (list major-mode (geiser-impl--guess))))
    (quote ("/tmp/flight-tests/guile/main.scm"
            "/tmp/flight-tests/chez/hello.scm"
            "/tmp/flight-tests/gambit/hello.scm")))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "((scheme-mode guile) (scheme-mode chez) (scheme-mode gambit))" ]]
}

@test "opening a .scm file activates scheme-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.scm") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "scheme-mode" ]]
}

@test "Geiser autodetects Chez from its precise .def extension" {
  run eval_elisp '(mapcar
    (lambda (file)
      (with-current-buffer (find-file-noselect file)
        (list major-mode (geiser-impl--guess))))
    (quote ("/tmp/smoketest/test-chez-extension.def")))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "((scheme-mode chez))" ]]
}

@test "a shared .ss file with Chez content selects Chez" {
  run timeout 10 emacsclient --eval '(with-current-buffer
    (find-file-noselect "/tmp/smoketest/test-chez-content.ss")
    (list major-mode (geiser-impl--guess)))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "(scheme-mode chez)" ]]
}

@test "a shared .ss file with Gerbil content selects Gerbil" {
  run timeout 10 emacsclient --eval '(with-current-buffer
    (find-file-noselect "/tmp/smoketest/test-gerbil-content.ss")
    major-mode)'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "gerbil-mode" ]]
}

@test "a shared .ss file with ambiguous content remains unresolved" {
  run eval_elisp '(with-temp-buffer
    (insert-file-contents "/tmp/smoketest/test-ambiguous.ss")
    (list (+geiser-chez-buffer-p)
          (+geiser-gambit-buffer-p)
          (geiser-guile--guess)
          (seq-some
           (lambda (entry)
             (and (eq (caar entry) (quote regexp))
                  (string-match-p "\\\\.ss" (cadar entry))
                  (cadr entry)))
           geiser-implementations-alist)))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "(nil nil nil nil)" ]]
}

@test "opening a detected Scheme file automatically starts its Geiser REPL" {
  run eval_elisp '(progn
    (require (quote geiser-repl))
    (dolist (repl (copy-sequence geiser-repl--repls))
      (when-let ((process (get-buffer-process repl))) (delete-process process))
      (when (buffer-live-p repl) (kill-buffer repl)))
    (setq geiser-repl--repls nil)
    (mapcar
     (lambda (case)
       (let* ((file (car case))
              (expected (cdr case))
              (existing (get-file-buffer file)))
         (when existing (kill-buffer existing))
         (with-current-buffer (find-file-noselect file)
           (let ((deadline (+ (float-time) 20)))
             (while (and (< (float-time) deadline)
                         (not (geiser-repl--live-p)))
               (accept-process-output nil 0.2)))
           (list (geiser-impl--guess)
                 (and (geiser-repl--live-p) t)
                 (and (buffer-live-p geiser-repl--repl)
                      (with-current-buffer geiser-repl--repl
                        geiser-impl--implementation))))))
     (quote (("/tmp/flight-tests/chez/hello.scm" . chez)
             ("/tmp/flight-tests/gambit/hello.scm" . gambit)
             ("/tmp/flight-tests/guile/main.scm" . guile)))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "((chez t chez) (gambit t gambit) (guile t guile))" ]]
}

@test "detected Scheme buffers display their dialect in the mode line" {
  run eval_elisp '(mapcar
    (lambda (file)
      (with-current-buffer (find-file-noselect file) mode-name))
    (quote ("/tmp/flight-tests/chez/hello.scm"
            "/tmp/flight-tests/gambit/hello.scm"
            "/tmp/flight-tests/guile/main.scm")))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '("Chez Scheme" "Gambit Scheme" "Guile Scheme")' ]]
}

@test "Geiser activates and evaluates through the Guile REPL" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/guile/main.scm")
    (let ((source (current-buffer)))
      (save-window-excursion (geiser-repl-switch nil (quote guile) source))
      (with-current-buffer source
        (goto-char (point-max))
        (let ((start (point)))
          (insert "\n(+ 20 22)")
          (list (bound-and-true-p geiser-mode)
                (geiser-eval-region/wait start (point) 20))))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(t" ]]
  [[ "$output" =~ "42" ]]
}

@test "Geiser evaluates through the Chez REPL" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/chez/hello.scm")
    (let ((source (current-buffer)))
      (save-window-excursion (geiser-repl-switch nil (quote chez) source))
      (with-current-buffer source
        (goto-char (point-max))
        (let ((start (point)))
          (insert "\n(+ 20 22)")
          (geiser-eval-region/wait start (point) 20)))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "42" ]]
}

@test "Geiser evaluates through the Gambit REPL" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/gambit/hello.scm")
    (let ((source (current-buffer)))
      (save-window-excursion (geiser-repl-switch nil (quote gambit) source))
      (with-current-buffer source
        (goto-char (point-max))
        (let ((start (point)))
          (insert "\n(+ 20 22)")
          (geiser-eval-region/wait start (point) 20)))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "42" ]]
}

@test "Geiser completion returns suggestions for Guile, Chez, and Gambit" {
  while read -r file implementation; do
    run completion_contains_for "/tmp/flight-tests/$file" "$implementation" displ display
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" == "t" ]]
  done <<'EOF'
guile/main.scm guile
chez/hello.scm chez
gambit/hello.scm gambit
EOF
}

@test "Guile completion finds an exported definition in an unopened sibling module" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/guile/main.scm")
    (not (null (member "greet"
                       (+scheme-company-project-symbols (quote candidates) "gr")))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "t" ]]
}

@test "Scheme completion includes user-defined symbols from flight buffers" {
  while read -r file prefix candidate; do
    run eval_elisp "(progn
      (find-file \"/tmp/flight-tests/$file\")
      (list
       (member 'company-dabbrev-code (flatten-tree company-backends))
       (member \"$candidate\"
               (company-dabbrev-code 'candidates \"$prefix\"))))"
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "company-dabbrev-code" ]]
    [[ "$output" =~ "$candidate" ]]
  done <<'EOF'
chez/hello.scm gr greet
chez/hello.scm jos josiah-greet
gambit/hello.scm gr greet
guile/utils.scm gr greet
EOF
}

@test "Gambit Company suggestions combine vocabulary and local definitions" {
  while read -r prefix candidate; do
    run eval_elisp "(progn
      (find-file \"/tmp/flight-tests/gambit/hello.scm\")
      (goto-char (point-max))
      (insert \"\n($prefix\")
      (let ((company-backend
             (seq-find
              (lambda (backend)
                (and (listp backend)
                     (memq 'company-dabbrev-code backend)))
              company-backends)))
        (not (null (member \"$candidate\"
                           (company-call-backend 'candidates))))))"
    echo "$prefix -> $candidate: $output"
    [ "$status" -eq 0 ]
    [[ "$output" == "t" ]]
  done <<'EOF'
def define
dis display
gr greet
EOF
}

@test "Emacs Lisp completion returns native suggestions" {
  run completion_contains_for /tmp/smoketest/test.el "" mes message
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == "t" ]]
}

@test "flycheck-guile connects for scheme-mode buffers ((scheme +guile))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.scm") (list (bound-and-true-p flycheck-mode) (flycheck-get-checker-for-buffer)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(t guile)" ]]
}

@test "guile localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.scm") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

# Chez and Gambit both ride on the same generic scheme-mode/apheleia/
# localleader wiring guile's own tests above already cover (Doom's +chez/
# +gambit flags add nothing beyond the geiser-chez/geiser-gambit
# packages themselves -- confirmed against doomemacs's own
# modules/lang/scheme/config.el, no per-backend config.el branch exists
# for either). Neither Chez nor Gambit has any flycheck/LSP checker
# package in this image (only Guile does, via flycheck-guile) -- so
# there is nothing to test there beyond binary presence.
@test "chez is installed and reports the pinned version (10.4.1)" {
  run scheme --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "10.4.1" ]]
}

@test "gambit is installed and reports the pinned version (4.9.7)" {
  run gsi -v
  [ "$status" -eq 0 ]
  [[ "$output" =~ "v4.9.7" ]]
}

# These exercise the actual scheme-config.el fix (DECISIONLOG.md's
# "Multi-backend Geiser ... hangs whole daemon" entry): each fixture
# below carries only a content-based giveaway (no `-*- geiser-scheme-
# implementation: ... -*-` file-local override like test.scm above),
# so a correct resolution here proves `geiser-impl--guess' picks the
# right backend via `check-buffer' on its own. Calling `geiser-impl--
# guess' with no PROMPT arg is safe under a headless emacsclient --
# eval: per its definition in geiser-impl.el, it returns nil rather
# than falling through to the interactive `y-or-n-p' prompt that used
# to hang the daemon.
@test "opening a Chez-marked .scm file auto-detects chez (check-buffer, no prompt)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test-chez-auto.scm") (symbol-name (geiser-impl--guess)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "chez" ]]
}

@test "opening a Gambit-marked .scm file auto-detects gambit (check-buffer, no prompt)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test-gambit-auto.scm") (symbol-name (geiser-impl--guess)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "gambit" ]]
}

@test "opening a Guile-marked .scm file auto-detects guile (check-buffer, no prompt)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test-guile-auto.scm") (symbol-name (geiser-impl--guess)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "guile" ]]
}

@test "reloading scheme-config does not duplicate Geiser methods or advice" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test-chez-auto.scm")
    (geiser-impl--guess)
    (load-file "~/.config/doom/scheme-config.el")
    (load-file "~/.config/doom/scheme-config.el")
    (list
     (cl-count (quote check-buffer)
               (cdr (assq (quote chez) geiser-impl--registry))
               :key (function car))
     (and (advice-member-p (function +geiser--remember-implementation-a)
                           (quote geiser-impl--read-impl))
          t)))'
  [ "$status" -eq 0 ]
  [[ "$output" == "(1 t)" ]]
}

@test "flycheck-guile also connects for a content-auto-detected (non-pinned) Guile buffer" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test-guile-auto.scm") (list (bound-and-true-p flycheck-mode) (flycheck-get-checker-for-buffer)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(t guile)" ]]
}

@test "racket is installed and reports the pinned version (9.2)" {
  run racket --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "9.2" ]]
}

@test "racket-langserver, rash, and fmt are raco pkg show-visible" {
  run raco pkg show racket-langserver rash fmt
  [ "$status" -eq 0 ]
  [[ "$output" =~ "racket-langserver" ]]
  [[ "$output" =~ "rash" ]]
  [[ "$output" =~ "fmt" ]]
}

@test "opening a .rkt file activates racket-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rkt") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "racket-mode" ]]
}

@test "racket-langserver connects for racket-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.rkt")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "racket-langserver" ]]
}

# Not just "does #lang racket work" -- racket-langserver's own docs describe
# its analysis as working via DrRacket's public API, which is #lang-generic
# in principle but unverified in practice for a non-core #lang until checked.
# Confirmed live (see ROADMAP.md Step 11.5/DECISIONLOG.md) that it holds up
# for #lang rash too, not just degrading to an empty/inert connection.
@test "racket-langserver also connects for a #lang rash buffer, not just plain #lang racket" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test-rash.rkt")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "racket-langserver" ]]
}

# Not "does SPC m f resolve to apheleia-format-buffer" -- confirmed live that
# it doesn't for racket-mode specifically: Doom's own racket module claims
# localleader "f" for `racket-fold-all-tests`, unlike every other language in
# this image, so that generic keybinding check (which works fine elsewhere)
# would be flatly wrong here. Tests the same underlying formatter
# configuration format-on-save actually uses (`apheleia-mode-alist`'s
# racket-mode entry, populated by Doom's `set-formatter!` inside racket's
# `:config` block), invoked directly with a completion callback rather than
# going through `save-buffer` + guessing how long a real save takes to
# settle: `set-formatter!` defers its registration inside `(after! apheleia
# ...)`, so `(require 'apheleia)` up front is what actually populates
# `apheleia-mode-alist`'s racket-mode entry (confirmed live: without forcing
# this load, the entry plain doesn't exist yet in a fresh session -- a
# real, generic laziness quirk, not specific to raco-fmt or this test). A
# callback-based wait is used instead of polling the buffer's own content
# for a substring match -- confirmed live that `raco fmt`'s actual process
# runtime varies enough (cold vs. warm racket process, overall system load
# during a full test run) that guessing a deadline against buffer content
# is fragile; the callback fires exactly when apheleia itself considers the
# format done, whatever that took.
@test "racket format-on-save formatter (raco fmt) actually reformats" {
  run eval_elisp '(with-current-buffer (find-file-noselect "/tmp/smoketest/test-fmt.rkt")
    (require (quote apheleia))
    (let ((done nil))
      (apheleia-format-buffer
       (alist-get major-mode apheleia-mode-alist)
       (lambda (&rest _) (setq done t)))
      (let ((deadline (+ (float-time) 30)))
        (while (and (not done) (< (float-time) deadline))
          (sleep-for 0.2)))
      (count-lines (point-min) (point-max))))'
  [ "$status" -eq 0 ]
  # test-fmt.rkt's deliberately-split call is 3 lines; raco fmt collapses it
  # to 2 ("#lang racket" + "(displayln \"hi\")"). Checked via line count, not
  # a string match against emacsclient's own prin1-escaped output (which
  # backslash-escapes embedded quotes -- confirmed live this made an
  # otherwise-correct plain-string comparison fail, a test bug, not a real
  # one).
  [[ "$output" == "2" ]]
}

@test "gerbil is installed and reports a version" {
  run gerbil -v
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Gerbil" ]]
}

@test "opening a .ss file activates gerbil-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ss") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "gerbil-mode" ]]
}

@test "gerbil localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ss") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "gerbil localleader eval uses cmuscheme, not inherited Geiser" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ss") (key-binding (kbd "SPC m e d")))'
  [ "$status" -eq 0 ]
  [[ "$output" == "scheme-send-definition" ]]
}

# The keybinding test above only proves gerbil-keybindings.el's own map
# shadows the inherited binding -- it would pass even if `geiser-mode'
# were also active underneath. This test targets the actual root-cause
# fix instead (scheme-config.el's `+geiser--activate-mode-h'): since
# `gerbil-mode' derives from `scheme-mode', `scheme-mode-hook' fires for
# gerbil-mode buffers too (`run-mode-hooks' walks the derived-mode parent
# chain), so without the `(eq major-mode 'scheme-mode)' guard Geiser
# would turn itself on there as well.
@test "geiser-mode does not activate in a gerbil-mode buffer" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ss") (bound-and-true-p geiser-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" == "nil" ]]
}

@test "Gerbil Company completion returns Scheme syntax, Gerbil forms, and local definitions" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/gerbil/hello.ss")
    (let ((results (list major-mode)))
      (dolist (case (quote (("de" "define") ("la" "lambda")
                            ("se" "set!") ("pa" "package:")
                            ("de" "def") ("gr" "greet"))))
        (goto-char (point-max))
        (let ((start (point)))
          (insert "\n(" (car case))
          (company-manual-begin)
          (setq results
                (append results
                        (list (and (member (cadr case) company-candidates) t))))
          (company-abort)
          (delete-region start (point-max))))
      results))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '(gerbil-mode t t t t t t)' ]]
}

@test "opening a .c file activates c-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "c-mode" ]]
}

@test "opening a .cpp file activates c++-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.cpp") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "c++-mode" ]]
}

@test "opening a .h file activates c-mode (Doom's default header fallback)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/header-only.h") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "c-mode" ]]
}

@test "opening a .mm file activates objc-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.mm") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "objc-mode" ]]
}

@test "opening CMakeLists.txt activates cmake-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/CMakeLists.txt") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "cmake-mode" ]]
}

@test "clangd connects when a c-mode buffer is opened ((cc +lsp))" {
  run lsp_servers_for /tmp/smoketest/test.c
  [ "$status" -eq 0 ]
  [[ "$output" =~ "clangd" ]]
}

@test "cmakels connects when a cmake-mode buffer is opened ((cc +lsp))" {
  run lsp_servers_for /tmp/smoketest/CMakeLists.txt
  [ "$status" -eq 0 ]
  [[ "$output" =~ "cmakels" ]]
}

@test "opening a .lua file activates lua-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.lua") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "lua-mode" ]]
}

@test "lua-language-server connects when a lua-mode buffer is opened" {
  run lsp_servers_for /tmp/smoketest/test.lua
  [ "$status" -eq 0 ]
  [[ "$output" =~ "lua-language-server" ]]
}

@test "opening a .py file activates python-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.py") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "python-mode" ]]
}

@test "pyright connects when a python-mode buffer is opened" {
  run lsp_servers_for /tmp/smoketest/test.py
  [ "$status" -eq 0 ]
  [[ "$output" =~ "pyright" ]]
}

@test "opening a .rb file activates ruby-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rb") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ruby-mode" ]]
}

@test "lsp-mode loads when a ruby-mode buffer is opened ((ruby +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rb") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

# Regression test: rubocop also registers its own LSP client (rubocop-ls,
# from `rubocop --lsp`) for ruby-mode, and used to silently win the
# client-priority contest over ruby-lsp-ls (see config.el's
# lsp-disabled-clients comment) -- lsp-mode would report "loaded" and
# "on" with rubocop-ls alone attached, but rubocop's LSP server only
# implements diagnostics/formatting, never completion. Asserting the
# featurep check above passes is not enough to catch that; this asserts
# the actually-useful server is the one that connects.
@test "ruby-lsp-ls (not rubocop-ls) connects for ruby-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.rb")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ruby-lsp-ls" ]]
  [[ ! "$output" =~ "rubocop-ls" ]]
}

@test "opening a .js file activates js-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.js") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "js" ]]
}

@test "lsp-mode loads when a js-mode buffer is opened ((javascript +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.js") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

# Regression test: typescript-language-server needs the classic
# lib/tsserver.js that TypeScript 7.0's native (Go-ported) rewrite
# dropped -- see the Dockerfile's typescript pin comment. ts-ls would
# still report a successful initial connection in the log, then crash
# moments later with "Unable to find tsserver" once it actually tried to
# load the typescript package, leaving lsp-workspaces empty. The featurep
# check above passes either way; this catches the actual crash.
@test "ts-ls connects and stays connected for js-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.js")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (sleep-for 2)
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ts-ls" ]]
}

@test "opening a .ts file activates typescript-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ts") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "typescript-mode" ]]
}

@test "lsp-mode loads and ts-ls connects for typescript-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.ts")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (sleep-for 2)
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ts-ls" ]]
}

# `.ts' files use typescript-mode -- a separate keymap from js-mode-map --
# and Doom's own :lang javascript module never wires SPC m f (or anything
# else) for it. Confirmed by opening a .ts file before
# typescript-keybindings.el existed: SPC m f resolved to nil.
@test "typescript localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.ts") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "dape's built-in gdb debug config covers c-mode/c++-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (let ((modes (plist-get (alist-get (quote gdb) dape-configs) (quote modes)))) (list (memq (quote c-mode) modes) (memq (quote c++-mode) modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "c-mode" ]]
  [[ "$output" =~ "c++-mode" ]]
}

@test "dape launches gdb, hits a breakpoint, and reads a real local value" {
  run eval_elisp '(progn
    (require (quote dape))
    (find-file "/tmp/smoketest/test.c")
    (goto-char (point-min))
    (forward-line 2)
    (dape-breakpoint-remove-all)
    (dape-breakpoint-toggle)
    (let ((config (copy-tree (alist-get (quote gdb) dape-configs))))
      (setq config (plist-put config :program "/tmp/smoketest/test-c-debug"))
      (setq config (plist-put config (quote command-cwd) "/tmp/smoketest/"))
      (dape config))
    (let ((deadline (+ (float-time) 30)) conn frame result error)
      (while (and (< (float-time) deadline)
                  (not (setq conn (dape--live-connection (quote stopped) t))))
        (sleep-for 0.2))
      (while (and conn (< (float-time) deadline)
                  (not (setq frame (dape--current-stack-frame conn))))
        (sleep-for 0.2))
      (when frame
        (let ((dape--request-blocking t))
          (dape--evaluate-expression
           conn (plist-get frame :id) "value" "watch"
           (lambda (body request-error)
             (setq result (plist-get body :result)
                   error request-error)))))
      (when conn (dape-kill (dape--root-of conn)))
      (list (plist-get frame :name) result error)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "main" ]]
  [[ "$output" =~ "42" ]]
  [[ "$output" =~ "nil)" ]]
}

@test "Dape/Delve hits a Go breakpoint and evaluates a local" {
  run go build -gcflags=all=-N\ -l -o /tmp/flight-tests/go/flight-test \
    /tmp/flight-tests/go/flight-test.go
  echo "$output"
  [ "$status" -eq 0 ]
  run dape_launch_for /tmp/flight-tests/go/flight-test.go dlv "" \
    /tmp/flight-tests/go/ "fmt.Println(debugValue)" debugValue
  echo "Go/Delve: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t "main.main" "42" nil stopped "breakpoint")' ]]
}

@test "Dape/LLDB hits Rust main, steps source, and evaluates a local" {
  run cargo build --manifest-path /tmp/flight-tests/rust/Cargo.toml
  echo "$output"
  [ "$status" -eq 0 ]
  run dape_launch_for /tmp/flight-tests/rust/src/main.rs lldb-dap \
    /tmp/flight-tests/rust/target/debug/flight-test /tmp/flight-tests/rust/ \
    'println!(\"{debug_value}\")' debug_value flight_test::main 3
  echo "Rust/LLDB: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t "flight_test::main" "42" nil stopped "step")' ]]
}

@test "Dape/LLDB hits a Zig breakpoint and evaluates a local" {
  run dape_launch_for /tmp/flight-tests/zig/src/main.zig lldb-dap \
    "" /tmp/flight-tests/zig/ \
    'std.debug.print(\"{d}\\n\", .{debug_value})' debug_value
  echo "Zig/LLDB: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t "main.main" "42" nil stopped "breakpoint")' ]]
}

@test "Dape/local-lua-debugger hits a Lua breakpoint and evaluates a local" {
  run dape_launch_for /tmp/flight-tests/lua/init.lua lua-local "" \
    /tmp/flight-tests/lua/ "for name, value" options.tabstop
  echo "Lua/local-lua-debugger: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t' ]]
  [[ "$output" =~ '"2" nil stopped "breakpoint")' ]]
}

@test "Dape/debugpy hits a Python breakpoint and evaluates a local" {
  run dape_launch_for /tmp/flight-tests/python/deploy.py debugpy \
    /tmp/flight-tests/python/deploy.py /tmp/flight-tests/python/ \
    "print(debug_value)" debug_value
  echo "Python/debugpy: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t' ]]
  [[ "$output" =~ '"42" nil stopped "breakpoint")' ]]
}

@test "Dape/GDB hits an Assembly breakpoint and evaluates a register" {
  timeout 5 emacsclient --eval '(kill-emacs)' >/dev/null 2>&1 || true
  pkill -TERM emacs >/dev/null 2>&1 || true
  start_emacs_daemon
  run gcc -g /tmp/smoketest-nomarkers/test.s -o /tmp/smoketest-nomarkers/a.out
  echo "$output"
  [ "$status" -eq 0 ]
  run dape_launch_for /tmp/smoketest-nomarkers/test.s gdb \
    /tmp/smoketest-nomarkers/a.out /tmp/smoketest-nomarkers/ "mov w1, w0" '$w0'
  echo "Assembly/GDB: $output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ '(t' ]]
  [[ "$output" =~ '"42" nil stopped "breakpoint")' ]]
}

# Regression test for a real bug: dape's own built-in gdb config never
# listed asm-mode (only c-mode/c++-mode/hare-mode variants), and
# +dape-resolve-cwd's fallback (dape-command-cwd) resolved to the
# broken "//" for any file with no Cargo.toml/CMakeLists.txt anywhere
# up its directory tree -- gdb then silently never found the relative
# :program "a.out", every breakpoint sat pending forever, and the
# adapter's own output buffer stayed completely empty (no error, just
# nothing). Confirmed live, end to end, after both fixes: assembling a
# real aarch64 binary with debug symbols, setting a breakpoint via
# dape-breakpoint-toggle, launching dape's gdb config, and stepping
# through it -- execution stopped at the exact breakpoint line, w0/w1
# showed the correct pre-computed values (5, 10), and w2 correctly
# showed 15 after stepping over the add instruction.
@test "dape's built-in gdb debug config covers asm-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (memq (quote asm-mode) (plist-get (alist-get (quote gdb) dape-configs) (quote modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "asm-mode" ]]
}

@test "reloading dape-config does not duplicate added debugger modes" {
  run eval_elisp '(progn
    (require (quote dape))
    (load-file "~/.config/doom/dape-config.el")
    (load-file "~/.config/doom/dape-config.el")
    (list
     (cl-count (quote asm-mode)
               (plist-get (alist-get (quote gdb) dape-configs) (quote modes)))
     (cl-count (quote zig-mode)
               (plist-get (alist-get (quote lldb-dap) dape-configs) (quote modes)))))'
  [ "$status" -eq 0 ]
  [[ "$output" == "(1 1)" ]]
}

# Uses /tmp/smoketest-nomarkers/, not /tmp/smoketest/asm/ -- confirmed live
# that /tmp/smoketest/asm/test.s doesn't actually exercise the "zero markers
# anywhere" case this test means to check: /tmp/smoketest/'s own
# CMakeLists.txt fixture (added for the C/CMake tests) is a real ancestor
# match `locate-dominating-file` finds regardless of how deep the asm
# fixture is nested under it, so that path was silently testing "walks up
# to the nearest CMakeLists.txt," the opposite of what the test claims and
# not what it's named for -- see setup_file's own comment on
# /tmp/smoketest-nomarkers/ for the full reasoning.
@test "+dape-resolve-cwd falls back to the buffer's own directory, not the broken dape-command-cwd root-walk" {
  run eval_elisp '(progn (require (quote dape)) (find-file "/tmp/smoketest-nomarkers/test.s") (string= (+dape-resolve-cwd) (file-name-directory (buffer-file-name))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "dape's built-in lldb-dap debug config covers rustic-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (let ((modes (plist-get (alist-get (quote lldb-dap) dape-configs) (quote modes)))) (list (memq (quote rustic-mode) modes) (memq (quote rust-mode) modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "rustic-mode" ]]
  [[ "$output" =~ "rust-mode" ]]
}

# Regression test: lldb-dap's launch handler treats a denied personality()
# syscall (ASLR-disable, blocked by this container's default seccomp profile)
# as fatal, unlike gdb which just warns -- :disableASLR nil skips the syscall
# entirely. plist-member (not plist-get) used deliberately: plist-get alone
# can't distinguish "key present with value nil" from "key absent", and the
# whole point here is confirming the patch actually added the key.
@test "lldb-dap/lldb-vscode dape configs have :disableASLR nil (seccomp workaround, DECISIONLOG.md)" {
  run eval_elisp '(progn (require (quote dape))
    (list (plist-member (alist-get (quote lldb-dap) dape-configs) :disableASLR)
          (plist-member (alist-get (quote lldb-vscode) dape-configs) :disableASLR)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(:disableASLR nil" ]]
}

# Regression test: dape sends `launch` unconditionally, racing lldb-dap's own
# `initialized` event -- if breakpoints (sent on `initialized`) land after
# `launch` already took effect, the program just runs to completion, ignored.
# :stopOnEntry t halts at the first instruction, giving `setBreakpoints` time
# to land first. See DECISIONLOG.md's "lldb-dap ignores every breakpoint" entry.
@test "lldb-dap/lldb-vscode dape configs have :stopOnEntry t (launch/breakpoint race fix)" {
  run eval_elisp '(progn (require (quote dape))
    (list (plist-get (alist-get (quote lldb-dap) dape-configs) :stopOnEntry)
          (plist-get (alist-get (quote lldb-vscode) dape-configs) :stopOnEntry)))'
  [ "$status" -eq 0 ]
  [[ "$output" == "(t t)" ]]
}

# Regression test: dlv's own command-cwd (dape's default, ultimately
# project-current -> project-projectile) resolves to the outer git root for
# any Go project nested inside this repo's own tree, not the actual go.mod
# directory -- +dape-go-root walks up for go.mod directly instead.
@test "dlv's dape command-cwd resolves via +dape-go-root, not dape's own project-root guess" {
  run eval_elisp '(progn (require (quote dape)) (eq (plist-get (alist-get (quote dlv) dape-configs) (quote command-cwd)) (function +dape-go-root)))'
  [ "$status" -eq 0 ]
  [[ "$output" == "t" ]]
}

# dape has no built-in Lua config -- this is a from-scratch entry, not a
# patch to an upstream one like gdb/lldb-dap/dlv above. Verifies the shape
# specific to local-lua-debugger-vscode's own launch schema: a nested
# :program plist (:lua/:file, not a bare string like every other config in
# this file) and an explicit :extensionPath (not derivable by the adapter
# itself -- normally injected by VS Code's extension host).
@test "dape's lua-local debug config wires local-lua-debugger-vscode correctly" {
  run eval_elisp '(progn (require (quote dape))
    (find-file "/tmp/flight-tests/lua/init.lua")
    (let* ((config (alist-get (quote lua-local) dape-configs))
           (program (funcall (plist-get config :program))))
      (list (plist-get config (quote modes))
            (plist-get config :type)
            (equal (plist-get program :lua) "lua")
            (string= (plist-get program :file) (buffer-file-name))
            (stringp (plist-get config :extensionPath)))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(lua-mode)" ]]
  [[ "$output" =~ "lua-local" ]]
  [[ "$output" =~ "t t t)" ]]
}

# +dape-lua-file/+dape-lua-cwd deliberately use buffer-file-name directly
# rather than a marker-file walk -- a Lua script being debugged rarely has a
# project manifest to anchor a root search on (see dape-config.el's own
# Commentary on this). Confirms both resolve against the real buffer, not a
# stale/guessed default-directory.
@test "+dape-lua-file/+dape-lua-cwd resolve the current buffer's own file directly" {
  run eval_elisp '(with-current-buffer (find-file-noselect "/tmp/smoketest/test.lua")
    (list (string= (+dape-lua-file) (buffer-file-name))
          (string= (+dape-lua-cwd) (file-name-directory (buffer-file-name)))))'
  [ "$status" -eq 0 ]
  [[ "$output" == "(t t)" ]]
}

@test "global debugger keybinding SPC d d resolves to dape (config/default +bindings)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (key-binding (kbd "SPC d d")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dape" ]]
}

@test "SPC d d selects Delve for Go without prompting for an adapter" {
  run eval_elisp '(progn
    (require (quote dape))
    (find-file "/tmp/flight-tests/go/flight-test.go")
    (let (selected prompted)
      (cl-letf (((symbol-function (quote dape))
                 (lambda (config &optional _skip-compile)
                   (setq selected config)))
                ((symbol-function (quote completing-read))
                 (lambda (&rest _) (setq prompted t) (error "unexpected prompt"))))
        (let ((command (key-binding (kbd "SPC d d"))))
          (call-interactively command)
          (list command (plist-get selected :type) prompted)))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '(+systems-dape "go" nil)' ]]
}

@test "SPC d d selects debugpy for Python without prompting for an adapter" {
  run eval_elisp '(progn
    (require (quote dape))
    (find-file "/tmp/flight-tests/python/deploy.py")
    (let (selected prompted)
      (cl-letf (((symbol-function (quote dape))
                 (lambda (config &optional _skip-compile)
                   (setq selected config)))
                ((symbol-function (quote completing-read))
                 (lambda (&rest _) (setq prompted t) (error "unexpected prompt"))))
        (let ((command (key-binding (kbd "SPC d d"))))
          (call-interactively command)
          (list command (plist-get selected :type) prompted)))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == '(+systems-dape "python" nil)' ]]
}

@test "SPC d b functionally toggles breakpoints before Dape loads" {
  run eval_elisp '(mapcar
    (lambda (file)
      (find-file file)
      (goto-char (point-min))
      (let ((command (key-binding (kbd "SPC d b"))))
        (list major-mode command (commandp command)
              (progn (call-interactively command)
                     (not (null (dape--breakpoints-at-point))))
              (progn (call-interactively command)
                     (null (dape--breakpoints-at-point))))))
    (quote ("/tmp/flight-tests/ruby/deploy.rb"
            "/tmp/flight-tests/rust/src/main.rs")))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *'(ruby-mode dape-breakpoint-toggle t t t)'* ]]
  [[ "$output" == *'(rustic-mode dape-breakpoint-toggle t t t)'* ]]
}

@test "global keybinding SPC o D resolves to docker (config/default :tools docker)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (key-binding (kbd "SPC o D")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "docker" ]]
}

@test "SPC o c toggles docker-command between docker and podman" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (setq docker-command "docker") (call-interactively (key-binding (kbd "SPC o c"))) docker-command)'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "podman" ]]
}

@test "global keybinding SPC b c resolves to flycheck-buffer" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (key-binding (kbd "SPC b c")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "flycheck-buffer" ]]
}

@test "sh localleader keybindings resolve (execute, debug)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (list (key-binding (kbd "SPC m e e")) (key-binding (kbd "SPC m d d"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(sh-execute-region realgud:zshdb)" ]]
}

@test "go localleader keybindings resolve (playground, add import)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.go") (list (key-binding (kbd "SPC m e")) (key-binding (kbd "SPC m I"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(+go/playground-yank go-import-add)" ]]
}

@test "rust localleader keybindings resolve (cargo build/run/test, format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rs") (list (key-binding (kbd "SPC m b b")) (key-binding (kbd "SPC m b r")) (key-binding (kbd "SPC m t a")) (key-binding (kbd "SPC m f"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(rustic-cargo-build rustic-cargo-run rustic-cargo-test apheleia-format-buffer)" ]]
}

@test "nix localleader keybindings resolve (format, update fetch)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nix") (list (key-binding (kbd "SPC m f")) (key-binding (kbd "SPC m p"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(nix-format-buffer nix-update-fetch)" ]]
}

@test "bats localleader keybindings resolve (run test, run file, run all)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bats") (list (key-binding (kbd "SPC m e e")) (key-binding (kbd "SPC m e b")) (key-binding (kbd "SPC m e a"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(bats-run-current-test bats-run-current-file bats-run-all)" ]]
}

@test "nu localleader keybindings resolve (execute region, execute buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nu") (list (key-binding (kbd "SPC m e e")) (key-binding (kbd "SPC m e b"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(+nu/run-region +nu/run-buffer)" ]]
}

@test "c localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "lsp-format-buffer" ]]
}

@test "lua localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.lua") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "lsp-format-buffer" ]]
}

@test "python localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.py") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "ruby localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.rb") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "javascript localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.js") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "apheleia formatter overrides resolve (python-mode -> ruff, ruby-mode -> rubocop)" {
  run eval_elisp '(progn (require (quote apheleia)) (list (alist-get (quote python-mode) apheleia-mode-alist) (alist-get (quote ruby-mode) apheleia-mode-alist)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(ruff rubocop)" ]]
}

@test "Python Ruff formatter actually applies the configured style" {
  run eval_elisp '(with-current-buffer (find-file-noselect "/tmp/smoketest/test-python-format.py")
    (require (quote apheleia))
    (let ((done nil))
      (apheleia-format-buffer
       (alist-get major-mode apheleia-mode-alist)
       (lambda (&rest _) (setq done t)))
      (let ((deadline (+ (float-time) 20)))
        (while (and (not done) (< (float-time) deadline))
          (sleep-for 0.2)))
      (list done
            (string-match-p "^  return \"hi\"$" (buffer-string))
            (string-match-p "^    return" (buffer-string)))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^\(t\ [0-9]+\ nil\)$ ]]
}

@test "Flycheck runs Ruff and reports concrete Python diagnostics" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test-python-lint.py")
    (flycheck-select-checker (quote python-ruff))
    (flycheck-buffer)
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline)
                  (not (memq flycheck-last-status-change (quote (finished errored)))))
        (sleep-for 0.2)))
    (list flycheck-checker flycheck-last-status-change
          (sort (delq nil (mapcar (lambda (error) (flycheck-error-id error))
                                  flycheck-current-errors))
                (function string-lessp))))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "python-ruff finished" ]]
  [[ "$output" =~ "F401" ]]
  [[ "$output" =~ "F821" ]]
}

@test "cmake localleader keybindings resolve (configure, build, rebuild, clean)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/CMakeLists.txt") (list (key-binding (kbd "SPC m b c")) (key-binding (kbd "SPC m b b")) (key-binding (kbd "SPC m b r")) (key-binding (kbd "SPC m b d"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(+cmake/configure +cmake/build +cmake/rebuild +cmake/clean)" ]]
}

# Regression test: +cmake--root must climb PAST a nested add_subdirectory()
# CMakeLists.txt (not independently buildable) to the outermost project
# root, not stop at the nearest one -- confirmed against the nested fixture
# under /tmp/smoketest/nested-cmake/, whose own outer ancestor is the
# top-level /tmp/smoketest/CMakeLists.txt fixture used by the test above.
@test "+cmake--root climbs a nested CMakeLists.txt to the outermost project root" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/nested-cmake/CMakeLists.txt") (string= (+cmake--root) "/tmp/smoketest/"))'
  [ "$status" -eq 0 ]
  [[ "$output" == "t" ]]
}

@test "+cmake--root refuses to operate outside a CMake project" {
  run eval_elisp '(let ((default-directory "/tmp/smoketest-nomarkers/"))
    (condition-case nil (+cmake--root) (user-error t)))'
  [ "$status" -eq 0 ]
  [[ "$output" == "t" ]]
}

@test "opening a .fish file activates fish-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.fish") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fish-mode" ]]
}

@test "fish-lsp connects for fish-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.fish")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fish-lsp" ]]
}

@test "fish localleader keybindings resolve (format buffer)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.fish") (key-binding (kbd "SPC m f")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "apheleia-format-buffer" ]]
}

@test "fish-indent is apheleia's default formatter for fish-mode" {
  run eval_elisp '(progn (require (quote apheleia)) (symbol-name (alist-get (quote fish-mode) apheleia-mode-alist)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fish-indent" ]]
}

@test "opening a .s file activates asm-mode" {
  # Regex anchored to the literal quoted string, not a bare substring
  # match -- "go-asm-mode" (go-mode.el's own derived mode, see
  # setup_file's comment on why this fixture lives in its own asm/
  # subdirectory) also contains "asm-mode" as a substring, so a loose
  # match here would silently false-pass even if go-mode's directory-
  # sniffing regressed and hijacked this buffer again.
  run eval_elisp '(progn (find-file "/tmp/smoketest/asm/test.s") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ \"asm-mode\" ]]
}

@test "asm-lsp connects for asm-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/asm/test.s")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "asm-lsp" ]]
}

# Perl deliberately stays syntax-only (no LSP, no localleader) -- perl-mode
# and the .pl/.pm auto-mode-alist mapping both ship built into Emacs core
# already, so this only needs to confirm the built-in default still holds,
# not that anything was wired up.
@test "opening a .pl file activates perl-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "perl-mode" ]]
}

# Haskell deliberately stays syntax-only too (see DECISIONLOG.md -- HLS's
# heavier, more failure-prone dependency profile isn't worth it for a
# shared polyglot image; a bare `(haskell)' with no +lsp/+tree-sitter flags
# installs only haskell-mode, confirmed directly against Doom's own
# lang/haskell/packages.el). Same shape as Perl above: confirm the mode
# activates, nothing more to wire up.
@test "opening a .hs file activates haskell-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.hs") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "haskell-mode" ]]
}

@test "opening a .zig file activates zig-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.zig") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "zig-mode" ]]
}

@test "lsp-mode loads and zls connects for zig-mode buffers ((zig +lsp))" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.zig")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "zls" ]]
}

# zig-fmt is apheleia's own built-in default formatter for zig-mode
# (confirmed directly in apheleia-formatters.el at this project's pinned
# commit), and Doom's zig module explicitly sets zig-format-on-save nil to
# defer to it -- same "require apheleia up front, callback-based wait,
# count-lines instead of a prin1-escaped string match" approach as the
# Racket format-on-save test above, same reasoning throughout.
@test "zig format-on-save formatter (zig-fmt) actually reformats" {
  run eval_elisp '(with-current-buffer (find-file-noselect "/tmp/smoketest/test-fmt.zig")
    (require (quote apheleia))
    (let ((done nil))
      (apheleia-format-buffer
       (alist-get major-mode apheleia-mode-alist)
       (lambda (&rest _) (setq done t)))
      (let ((deadline (+ (float-time) 30)))
        (while (and (not done) (< (float-time) deadline))
          (sleep-for 0.2)))
      (count-lines (point-min) (point-max))))'
  [ "$status" -eq 0 ]
  # test-fmt.zig's deliberately-split call is 6 lines; zig fmt collapses
  # the argument-less multi-line call onto one line (5 total), confirmed
  # live -- zig fmt only preserves a multi-line call shape when a trailing
  # comma is present, which this fixture deliberately omits.
  [[ "$output" == "5" ]]
}

@test "dape's built-in lldb-dap debug config covers zig-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (memq (quote zig-mode) (plist-get (alist-get (quote lldb-dap) dape-configs) (quote modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "zig-mode" ]]
}

@test "opening a .toml file activates toml-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.toml") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "toml-mode" ]]
}

@test "lsp-mode loads and taplo connects for toml-mode buffers" {
  run eval_elisp '(progn
    (find-file "/tmp/smoketest/test.toml")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (mapcar (function lsp--workspace-server-id) (lsp-workspaces)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "taplo" ]]
}

# polyglot-keybindings.el: cross-cutting dev-tooling, not language-specific,
# so placed here rather than under any one language's test group.
@test "SPC l w S keybinding resolves to +systems-lsp/pick-root" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (key-binding (kbd "SPC l w S")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "+systems-lsp/pick-root" ]]
}

@test "every LSP-backed flight project returns a concrete language result" {
  while read -r file server method needle expected; do
    run lsp_result_for "/tmp/flight-tests/$file" "$method" "$needle"
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$server" ]]
    [[ "$output" =~ "$expected" ]]
  done <<'EOF'
go/flight-test.go gopls textDocument/definition Counter{ flight-test.go
rust/src/main.rs rust-analyzer textDocument/definition Counter counter.rs
nu/toy.nu nushell-ls textDocument/documentSymbol - greet
racket/hello.rkt racket-langserver textDocument/documentSymbol - greet
c/src/main.c clangd textDocument/definition make_greeting( greet.h
lua/init.lua lua-language-server textDocument/definition greet utils.lua
python/deploy.py pyright textDocument/definition tasks.run tasks.py
javascript/script.js ts-ls textDocument/definition utils.run utils.js
typescript/deploy.ts ts-ls textDocument/definition checkPackage helpers.ts
zig/src/main.zig zls textDocument/definition counter.Counter counter.zig
EOF
}

@test "Racket LSP publishes diagnostics for a real Rash syntax error" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/racket/hello-rash.rkt")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (goto-char (point-max))
    (insert "\n(define broken (")
    (save-buffer)
    (let ((deadline (+ (float-time) 20)) diagnostics)
      (while (and (< (float-time) deadline)
                  (not (setq diagnostics
                             (gethash (buffer-file-name) (lsp-diagnostics t)))))
        (sleep-for 0.5))
      (length diagnostics)))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[1-9][0-9]*$ ]]
}

@test "every remaining LSP-backed language returns a concrete language result" {
  while read -r file server method needle expected; do
    run lsp_result_for "$file" "$method" "$needle"
    echo "$file: $output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$server" ]]
    [[ "$output" =~ "$expected" ]]
  done <<'EOF'
/tmp/smoketest/test.bash bash-ls textDocument/documentSymbol - greet
/tmp/smoketest/test.bats bash-ls textDocument/documentSymbol - addition
/tmp/smoketest/test.nix nix-nil textDocument/documentSymbol - answer
/tmp/smoketest/CMakeLists.txt cmakels textDocument/hover project project
/tmp/smoketest/test.fish fish-lsp textDocument/documentSymbol - greet
/tmp/smoketest/asm/test.s asm-lsp textDocument/documentSymbol - main
/tmp/smoketest/test.toml taplo textDocument/documentSymbol - package
EOF
}

@test "Ruby LSP publishes diagnostics for a real syntax error" {
  run eval_elisp '(progn
    (find-file "/tmp/flight-tests/ruby/deploy.rb")
    (let ((deadline (+ (float-time) 20)))
      (while (and (< (float-time) deadline) (not (lsp-workspaces)))
        (sleep-for 0.5)))
    (goto-char (point-max))
    (insert "\ndef broken(\n")
    (save-buffer)
    (let ((deadline (+ (float-time) 20)) diagnostics)
      (while (and (< (float-time) deadline)
                  (not (setq diagnostics
                             (gethash (buffer-file-name) (lsp-diagnostics t)))))
        (sleep-for 0.5))
      (length diagnostics)))'
  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[1-9][0-9]*$ ]]
}

# Doesn't call +systems-lsp/pick-root itself -- it ends in
# (call-interactively #'lsp),
# which reaches lsp-mode's real interactive root-selection prompt with no
# way to answer it under headless emacsclient (same class of hang the
# multi-backend Geiser fix elsewhere in this file avoids by never reaching
# an unanswerable interactive prompt). Exercises the same buffer-local
# override/restore mechanism directly instead: +systems-lsp/restore-auto-guess-root
# has no other built-in way to undo a buffer-local lsp-auto-guess-root
# override, so this confirms it actually kills the local binding rather
# than just setting it back to a guessed value.
@test "+systems-lsp/restore-auto-guess-root kills the buffer-local override" {
  run eval_elisp '(with-current-buffer (find-file-noselect "/tmp/smoketest/test.c")
    (let ((before lsp-auto-guess-root))
      (setq-local lsp-auto-guess-root nil)
      (let ((during (list lsp-auto-guess-root (local-variable-p (quote lsp-auto-guess-root)))))
        (+systems-lsp/restore-auto-guess-root)
        (list before during lsp-auto-guess-root (local-variable-p (quote lsp-auto-guess-root))))))'
  [ "$status" -eq 0 ]
  [[ "$output" == "(t (nil t) t nil)" ]]
}

@test "Doom loaded without error (nonzero package/module count)" {
  run eval_elisp '(list (hash-table-count doom-modules) (length (doom-package-list)))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "(0 " ]]
}
