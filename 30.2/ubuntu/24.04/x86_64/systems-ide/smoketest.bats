#!/usr/bin/env bats

# IDE smoketest for systems-ide (Shell + Go + Nix + Bats + Nushell + C/C++/CMake).
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
# nu, clang(d), gcc/g++, cmake, gdb, cmake-language-server, vcpkg, conan are
# all baked into the image at build time (no network/host bind mounts
# required). nu and clangd both double as their own LSP server, no separate
# language-server package needed for either. ccls is deliberately not
# installed (see Dockerfile) -- Doom's own :lang cc module already
# deprioritizes it below clangd. The nix CLI itself is checked separately in
# nix-smoketest.bats, since it depends on host bind mounts (see run.sh) not
# present here.

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
  cat > /tmp/smoketest/test.zsh <<'EOF'
#!/bin/zsh
echo hi
EOF
  cat > /tmp/smoketest/test.go <<'EOF'
package main

func main() {}
EOF
  cat > /tmp/smoketest/test.nix <<'EOF'
{ }
EOF
  cat > /tmp/smoketest/test.nu <<'EOF'
def main [] {
  echo "hi"
}
EOF
  cat > /tmp/smoketest/test.c <<'EOF'
int main(void) { return 0; }
EOF
  cat > /tmp/smoketest/test.cpp <<'EOF'
int main() { return 0; }
EOF
  cat > /tmp/smoketest/test.h <<'EOF'
#pragma once
EOF
  cat > /tmp/smoketest/test.mm <<'EOF'
int main() { return 0; }
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

@test "vcpkg is installed and reports the pinned version (2026.06.24)" {
  run vcpkg version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2026.06.24" ]]
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
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.h") (symbol-name major-mode))'
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

@test "dape's built-in gdb debug config covers c-mode/c++-mode (:tools debugger)" {
  run eval_elisp '(progn (require (quote dape)) (let ((modes (plist-get (alist-get (quote gdb) dape-configs) (quote modes)))) (list (memq (quote c-mode) modes) (memq (quote c++-mode) modes))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "c-mode" ]]
  [[ "$output" =~ "c++-mode" ]]
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

@test "cmake localleader keybindings resolve (configure, build, rebuild, clean)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/CMakeLists.txt") (list (key-binding (kbd "SPC m b c")) (key-binding (kbd "SPC m b b")) (key-binding (kbd "SPC m b r")) (key-binding (kbd "SPC m b d"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(+cmake/configure +cmake/build +cmake/rebuild +cmake/clean)" ]]
}

@test "Doom loaded without error (nonzero package/module count)" {
  run eval_elisp '(list (hash-table-count doom-modules) (length (doom-package-list)))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "(0 " ]]
}
