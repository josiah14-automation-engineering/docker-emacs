#!/usr/bin/env bats
# Smoketest for josiah14/guix:*-ubuntu-26.04 (aarch64)
# Run via:  ./run.sh --test
# No network access required: everything here is already baked into the image.

@test "guix version is 1.5.0" {
  run guix --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.5.0" ]]
}

@test "guile version is 3.0.9" {
  run guile --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3.0.9" ]]
}

@test "guile evaluates an expression" {
  run guile -c '(display (+ 1 2)) (newline)'
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

@test "guix, guix-daemon, and guile all resolve under ~/.local/bin" {
  run bash -c "ls -l ~/.local/bin | grep -cE ' (guix|guix-daemon|guile|guild) ->'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 4 ]
}

@test "no guix-daemon is running (this image never starts one)" {
  run pgrep -f guix-daemon
  [ "$status" -ne 0 ]
}
