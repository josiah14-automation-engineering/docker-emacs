#!/usr/bin/env bats
# Smoketest for josiah14/nix:*-ubuntu-26.04 (aarch64)
# Run via:  ./run.sh --test
# Network access required: the flake and direnv tests fetch nixpkgs.

setup_file() {
  cat > "$BATS_FILE_TMPDIR/flake.nix" <<'EOF'
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.aarch64-linux; in {
      devShells.aarch64-linux.default = pkgs.mkShell {
        packages = [ pkgs.jq ];
        SMOKETEST_OK = "yes";
      };
    };
}
EOF
  printf 'use flake\n' > "$BATS_FILE_TMPDIR/.envrc"
}

# ── image size ────────────────────────────────────────────────────────────────
# Ordered first: the flake tests below fetch nixpkgs and grow /nix to ~2G.

@test "/nix store is under 1G before flake fetch" {
  local bytes
  bytes="$(du -sb /nix | awk '{print $1}')"
  [ "$bytes" -lt 1073741824 ]
}

# ── tools ─────────────────────────────────────────────────────────────────────

@test "nix version is 2.34.7" {
  run nix --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2.34.7" ]]
}

@test "current system is aarch64-linux" {
  run nix eval --impure --raw --expr 'builtins.currentSystem'
  [ "$status" -eq 0 ]
  [ "$output" = "aarch64-linux" ]
}

@test "nil is on PATH" {
  run nil --version
  [ "$status" -eq 0 ]
}

@test "direnv is on PATH" {
  run direnv --version
  [ "$status" -eq 0 ]
}

# ── profile ───────────────────────────────────────────────────────────────────

@test "nix-profile bin contains nix, nil, and direnv symlinks" {
  run bash -c "ls -l ~/.nix-profile/bin | grep -cE ' (nix|nil|direnv) ->'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 3 ]
}

@test "~/.nix-profile resolves into ~/.local/state/nix/profiles/" {
  run readlink ~/.nix-profile
  [ "$status" -eq 0 ]
  [[ "$output" =~ ".local/state/nix/profiles/profile" ]]
}

@test "nix-direnv share/nix-direnv/direnvrc exists in profile" {
  [ -f "$HOME/.nix-profile/share/nix-direnv/direnvrc" ]
}

# ── config ────────────────────────────────────────────────────────────────────

@test "nix.conf enables pipe-operators" {
  run grep "pipe-operators" "$HOME/.config/nix/nix.conf"
  [ "$status" -eq 0 ]
}

@test "direnvrc sources nix-direnv" {
  run grep "nix-direnv/direnvrc" "$HOME/.config/direnv/direnvrc"
  [ "$status" -eq 0 ]
}

# ── nix evaluation ────────────────────────────────────────────────────────────

@test "nix eval: 1 + 1 = 2" {
  run nix eval --expr '1 + 1'
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "nix eval: pipe-operators are active" {
  run nix eval --expr '[1 2 3 4] |> builtins.length'
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]
}

# ── flake dev shell ───────────────────────────────────────────────────────────

@test "nix develop: dev shell activates and exposes jq" {
  run nix develop "$BATS_FILE_TMPDIR" -c bash -c 'printf "%s\n" "$SMOKETEST_OK" && jq --version'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "yes" ]]
  [[ "$output" =~ "jq-" ]]
}

# ── direnv + nix-direnv ───────────────────────────────────────────────────────

@test "direnv: nix-direnv hook activates flake env" {
  run bash -c "
    cd '${BATS_FILE_TMPDIR}'
    direnv allow . 2>/dev/null
    eval \"\$(direnv export bash 2>/dev/null)\"
    printf '%s\n' \"\${SMOKETEST_OK}\"
    which jq
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "yes" ]]
  [[ "$output" =~ "/nix/store" ]]
}
