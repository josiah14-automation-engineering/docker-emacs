# Smoke Test

Run these inside the container after a successful `./build.sh`. Drop in with `./run.sh`.

**Tools and versions**
```bash
nix --version            # nix (Nix) 2.34.7
nix-env --version
nil --version
direnv --version
```

**Profile**
```bash
ls -l ~/.nix-profile/bin | grep -E ' (nix|nil|direnv) ->'   # nix, nix-env, nix-build, nix-shell, nil, direnv
readlink ~/.nix-profile                                      # ~/.local/state/nix/profiles/profile (Nix 2.20+)
ls ~/.nix-profile/share/nix-direnv/direnvrc                  # target of the direnvrc source line
```

**Config**
```bash
cat ~/.config/nix/nix.conf       # experimental-features = ... with the full list, including pipe-operators
cat ~/.config/direnv/direnvrc    # source $HOME/.nix-profile/share/nix-direnv/direnvrc
```

**Language and CLI**
```bash
nix eval --expr '1 + 1'                          # 2
nix eval --expr '[1 2 3 4] |> builtins.length'   # 4    (exercises pipe-operators)
nix flake metadata nixpkgs                       # registry-default nixpkgs flake metadata
```

If `pipe-operators` is not picked up from nix.conf the second line errors at the parser.

**Flake dev shell (the workflow IDEs depend on)**

```bash
mkdir -p /tmp/flake-smoketest && cd /tmp/flake-smoketest
cat > flake.nix <<'EOF'
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux; in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.jq ];
        SMOKETEST_OK = "yes";
      };
    };
}
EOF
cat > .envrc <<'EOF'
use flake
EOF

nix develop -c bash -c 'echo "$SMOKETEST_OK" && jq --version'   # yes / jq-<version>
```

**direnv + nix-direnv hook**
```bash
direnv allow
eval "$(direnv export bash)"
echo "$SMOKETEST_OK"   # yes
which jq               # /nix/store/.../bin/jq
```

If both print the expected values, the hook is wired and downstream IDEs will get the same behavior.

**Image size sanity**

Run this *before* the flake dev shell test — the flake test pulls nixpkgs + package
closures into the store, growing it significantly.

```bash
du -sh /nix   # a few hundred MB (nil + direnv + nix-direnv closures only)
```

Several GB means `nix store gc` and `nix store optimise` did not run during build.
After the flake tests `/nix` will be ~2G+ due to the nixpkgs closure — that is normal.
