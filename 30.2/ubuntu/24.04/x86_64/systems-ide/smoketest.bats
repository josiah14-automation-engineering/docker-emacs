#!/usr/bin/env bats

# IDE smoketest for systems-ide (Shell + Go + Nix + Bats + Nushell).
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
# nu are all baked into the image at build time (no network/host bind mounts
# required). nu doubles as its own LSP server (`nu --lsp'), no separate
# language-server package needed. The nix CLI itself is checked separately in
# nix-smoketest.bats, since it depends on host bind mounts (see run.sh) not
# present here.

setup_file() {
  mkdir -p /tmp/smoketest
  cat > /tmp/smoketest/test.bash <<'EOF'
#!/bin/bash
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

@test "opening a .bash file activates sh-mode with the bash dialect" {
  # sh-mode is the only major mode for shell scripts; bash vs zsh is tracked
  # by the buffer-local sh-shell variable, not a separate major mode (this is
  # also why sh-keybindings.el binds sh-set-shell as "switch shell dialect").
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.bash") (format "%s %s" major-mode sh-shell))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sh-mode" ]]
  [[ "$output" =~ "bash" ]]
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

@test "Doom loaded without error (nonzero package/module count)" {
  run eval_elisp '(list (hash-table-count doom-modules) (length (doom-package-list)))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "(0 " ]]
}
