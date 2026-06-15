#!/usr/bin/env bats
# Nix integration smoketest for the mercury-ide container.
#
# Verifies the host /nix, ~/.local/state/nix, and ~/.config/nix bind mounts
# (see host/logic-languages-ide) give this container the same Nix store,
# config, and profile as the host CLI.
#
# Run via: bats nix-smoketest.bats
# No network access required.

@test "nix version matches the host (2.34.7)" {
  run nix --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.34.7" ]]
}

@test "nix store info reports a healthy, trusted local store" {
  run nix store info
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Trusted: 1" ]]
}

@test "nix.conf (bind-mounted from host) enables pipe-operators" {
  run grep "pipe-operators" "$HOME/.config/nix/nix.conf"
  [ "$status" -eq 0 ]
}

@test "nix eval: pipe-operators are active" {
  run nix eval --expr '[1 2 3 4] |> builtins.length'
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
}

@test "nix profile list reflects the shared host profile" {
  run nix profile list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "direnv" ]]
  [[ "$output" =~ "nil" ]]
  [[ "$output" =~ "bats" ]]
}

@test "nil and direnv are on PATH via the shared ~/.nix-profile" {
  run nil --version
  [ "$status" -eq 0 ]
  run direnv --version
  [ "$status" -eq 0 ]
}

@test "host-built hello package is visible in the bind-mounted /nix/store" {
  run bash -c 'ls /nix/store | grep -c -- "-hello-"'
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
