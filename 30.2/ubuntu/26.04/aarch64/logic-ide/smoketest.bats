#!/usr/bin/env bats
# IDE smoketest for logic-ide (Mercury + Prolog).
#
# Verifies the actual Doom Emacs session boots correctly and both languages'
# major modes, checkers, and keybindings resolve as configured -- not just
# that packages installed without error at build time.
#
# IMPORTANT: must run against a real (non-batch) Emacs daemon, not
# `emacs --batch`. Doom deliberately skips large parts of its own bootstrap
# (including UI-related variables like `doom-font', and by extension entire
# swaths of module config) when `noninteractive' is non-nil -- confirmed
# directly: `doom-font' is void and `auto-mode-alist' has no sweeprolog entry
# at all under --batch, even though the exact same check against a real
# `emacs --daemon' + `emacsclient --eval' session (the same technique used to
# test the host Emacs session interactively) shows everything working.
#
# Run via: bats smoketest.bats
# No network access required (SWI-Prolog and Mercury are both baked into the
# image at build time).

setup_file() {
  mkdir -p /tmp/smoketest
  cat > /tmp/smoketest/test.pl <<'EOF'
foo(X) :- bar(X).
EOF
  cat > /tmp/smoketest/test.m <<'EOF'
:- module test.
:- interface.
:- import_module io.
:- pred main(io::di, io::uo) is det.
:- implementation.
main(!IO).
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

@test "swipl is installed and reports a version" {
  run swipl --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SWI-Prolog" ]]
}

@test "mmc (Mercury compiler) is installed" {
  run mmc --version
  [ "$status" -eq 0 ]
}

@test "opening a .pl file activates sweeprolog-mode" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sweeprolog-mode" ]]
}

@test "sweeprolog package is loaded and flymake is active in .pl buffers" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (list (featurep (quote sweeprolog)) (bound-and-true-p flymake-mode)))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(t t)" ]]
}

@test "sweeprolog resolves swipl on PATH" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (executable-find "swipl"))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "/usr/bin/swipl" ]]
}

@test "prolog localleader quick actions resolve (SPC m c / SPC m r)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (list (key-binding (kbd "SPC m c")) (key-binding (kbd "SPC m r"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(sweeprolog-load-buffer sweeprolog-top-level)" ]]
}

@test "prolog localleader nested prefix group resolves (SPC m g m)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.pl") (key-binding (kbd "SPC m g m")))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sweeprolog-find-module" ]]
}

@test "opening a .m file still activates metal-mercury-mode (regression)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.m") (symbol-name major-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "metal-mercury-mode" ]]
}

@test "flycheck is still active in .m buffers (regression)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.m") (bound-and-true-p flycheck-mode))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "t" ]]
}

@test "mercury localleader quick actions still resolve (regression)" {
  run eval_elisp '(progn (find-file "/tmp/smoketest/test.m") (list (key-binding (kbd "SPC m c")) (key-binding (kbd "SPC m r"))))'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "(metal-mercury-mode-compile metal-mercury-mode-runner)" ]]
}

@test "Doom loaded without error (nonzero package/module count)" {
  run eval_elisp '(list (hash-table-count doom-modules) (length (hash-table-keys straight--packages)))'
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "(0 " ]]
}
