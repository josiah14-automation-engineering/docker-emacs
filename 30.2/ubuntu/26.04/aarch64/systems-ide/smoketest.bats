#!/usr/bin/env bats

# IDE smoketest for systems-ide (Shell + Go + Rust + Nix + Guile + Bats +
# Nushell + C/C++/CMake + Lua + Python/Ruby/JavaScript/TypeScript glue-script
# tier + Fish + Assembly + Perl syntax-only).
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
# nu, guile, clang(d), gcc/g++, cmake, gdb, cmake-language-server, vcpkg, conan, lua,
# lua-language-server, stylua, python3, pyright, ruff, ruby, ruby-lsp,
# rubocop, typescript-language-server, prettier, oxlint, cargo, rustc,
# rust-analyzer, rustfmt, clippy, lldb, fish, fish-lsp, asm-lsp are all baked
# into the image at build time (no network/host bind mounts required). nu and
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
  cat > /tmp/smoketest/test.bash <<'EOF'
#!/bin/bash
echo hi
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
echo hi
EOF
  cat > /tmp/smoketest/test.go <<'EOF'
package main

func main() {}
EOF
  cat > /tmp/smoketest/test.rs <<'EOF'
fn main() {
    println!("hi");
}
EOF
  cat > /tmp/smoketest/test.nix <<'EOF'
{ }
EOF
  cat > /tmp/smoketest/test.nu <<'EOF'
def main [] {
  echo "hi"
}
EOF
  cat > /tmp/smoketest/test.scm <<'EOF'
(display "hi")
(newline)
EOF
  cat > /tmp/smoketest/test.c <<'EOF'
int main(void) { return 0; }
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
echo "hi"
EOF
  cat > /tmp/smoketest/test.pl <<'EOF'
print "hi\n";
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
    mov w0, #0
    ret
EOF
  cat > /tmp/smoketest/CMakeLists.txt <<'EOF'
cmake_minimum_required(VERSION 3.10)
project(smoketest)
EOF
  cat > /tmp/smoketest/test.bats <<'EOF'
#!/usr/bin/env bats

@test "addition works" {
  result="$(( 2 + 2 ))"
  [ "$result" -eq 4 ]
}
EOF
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
  emacsclient --eval '(kill-emacs)' >/dev/null 2>&1 || true
}

eval_elisp() {
  emacsclient --eval "$1"
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
  # .bash extension to trigger this project's own bash-mode instead).
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

# featurep, not bound-and-true-p: (lsp-deferred) is an autoloaded stub, so
# calling it from the mode hook forces lsp-mode.el to load synchronously even
# though the actual server handshake is scheduled for the next idle moment.
# Asserting the minor mode is ON here would race that handshake.
@test "lsp-mode loads when a shell buffer is opened ((sh +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "opening a .go file activates go-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.go") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "go-mode" ]]
}

@test "lsp-mode loads and flycheck-golangci-lint is active in go buffers" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.go") (list (featurep (quote lsp-mode)) (bound-and-true-p flycheck-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(t t)" ]]
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

@test "opening a .nu file activates nushell-ts-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nu") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "nushell-ts-mode" ]]
}

@test "lsp-mode loads when a nushell buffer is opened (nu-config.el's local-vars hook)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.nu") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "guile is installed and reports a version" {
  run guile --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Guile" ]]
}

@test "opening a .scm file activates scheme-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.scm") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "scheme-mode" ]]
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

@test "lsp-mode loads when a c-mode buffer is opened ((cc +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "lsp-mode loads when a cmake-mode buffer is opened ((cc +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/CMakeLists.txt") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "opening a .lua file activates lua-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.lua") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "lua-mode" ]]
}

@test "lsp-mode loads when a lua-mode buffer is opened ((lua +lsp))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.lua") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "opening a .py file activates python-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.py") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "python-mode" ]]
}

@test "lsp-mode loads when a python-mode buffer is opened ((python +lsp +pyright))" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.py") (featurep (quote lsp-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
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

@test "+dape-resolve-cwd falls back to the buffer's own directory, not the broken dape-command-cwd root-walk" {
  run eval_elisp '(progn (require (quote dape)) (find-file "/tmp/smoketest/asm/test.s") (string= (+dape-resolve-cwd) (file-name-directory (buffer-file-name))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "dape's built-in lldb-dap debug config covers rustic-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (let ((modes (plist-get (alist-get (quote lldb-dap) dape-configs) (quote modes)))) (list (memq (quote rustic-mode) modes) (memq (quote rust-mode) modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "rustic-mode" ]]
  [[ "$output" =~ "rust-mode" ]]
}

@test "global debugger keybinding SPC d d resolves to dape (config/default +bindings)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.c") (key-binding (kbd "SPC d d")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dape" ]]
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
  [[ "$output" =~ "(nu-run-region nu-run-buffer)" ]]
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

@test "cmake localleader keybindings resolve (configure, build, rebuild, clean)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/CMakeLists.txt") (list (key-binding (kbd "SPC m b c")) (key-binding (kbd "SPC m b b")) (key-binding (kbd "SPC m b r")) (key-binding (kbd "SPC m b d"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(+cmake/configure +cmake/build +cmake/rebuild +cmake/clean)" ]]
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

@test "Doom loaded without error (nonzero package/module count)" {
  run eval_elisp '(list (hash-table-count doom-modules) (length (doom-package-list)))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "(0 " ]]
}
