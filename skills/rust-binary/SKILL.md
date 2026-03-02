---
name: rust-binary
description: Scaffold a simple Rust binary using substrate's mkCrate2nixTool builder. Use when creating a single-platform Rust binary or CLI tool that does not need cross-compilation or GitHub releases.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-01"
  domain_keywords:
    - "rust"
    - "binary"
    - "cli"
    - "tool"
    - "crate2nix"
---

# Rust Binary — Substrate Builder

## Overview

Simple single-platform binary. No cross-compilation, no GitHub releases, no Docker.
For cross-platform CLI tools with GitHub releases, use the `rust-tool` skill instead.

**Builder:** `substrate/lib/crate2nix-builders.nix` → `mkCrate2nixTool`

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
    crate2nix.url = "github:nix-community/crate2nix";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, substrate, crate2nix, fenix, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ substrate.overlays.${system}.rust ];
          };
          crate2nixTools = import "${crate2nix}/tools.nix" { inherit pkgs; };
          builders = import "${substrate}/lib/crate2nix-builders.nix" {
            inherit pkgs crate2nixTools system;
          };
          tool = builders.mkCrate2nixTool {
            toolName = "{binary-name}";
            src = self;
            cargoNix = ./Cargo.nix;
            # Optional:
            # buildInputs = [];
            # nativeBuildInputs = [];
            # runtimeDeps = [];       # Wrapped into PATH
            # crateOverrides = {};
          };
        in f { inherit tool pkgs; }
      );
    in {
      packages = forEachSystem ({ tool, ... }: {
        default = tool;
        {binary-name} = tool;
      });

      devShells = forEachSystem ({ pkgs, ... }: {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.fenixRustToolchain
            pkgs.rust-analyzer
            pkgs.cargo-watch
            pkgs.cargo-edit
          ];
          RUST_SRC_PATH = "${pkgs.fenixRustToolchain}/lib/rustlib/src/rust/library";
        };
      });

      apps = forEachSystem ({ tool, ... }: {
        default = {
          type = "app";
          program = "${tool}/bin/{binary-name}";
        };
      });

      overlays.default = final: prev: {
        {binary-name} = self.packages.${prev.system}.default;
      };
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `toolName` | yes | — | Binary name |
| `src` | yes | — | Source directory |
| `cargoNix` | no | `src + "/Cargo.nix"` | Path to generated Cargo.nix |
| `buildInputs` | no | `[]` | Additional build dependencies |
| `nativeBuildInputs` | no | `[]` | Additional native build dependencies |
| `runtimeDeps` | no | `[]` | Runtime dependencies wrapped into PATH via makeWrapper |
| `crateOverrides` | no | `{}` | Per-crate build overrides |

## Runtime Dependencies

If your binary needs other programs at runtime (e.g., `git`, `kubectl`), use `runtimeDeps`:

```nix
tool = builders.mkCrate2nixTool {
  toolName = "my-tool";
  src = self;
  runtimeDeps = with pkgs; [ git kubectl ];
};
```

This wraps the binary with `makeWrapper` so those programs are always in PATH.

## Initial File Layout

```
{binary-name}/
  Cargo.toml
  Cargo.lock
  Cargo.nix          # Generated: crate2nix generate (commit to git)
  flake.nix
  src/
    main.rs
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{binary-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{binary-name}.git
   cd {binary-name}
   ```

2. Initialize Cargo project:
   ```bash
   cargo init --name {binary-name}
   ```

3. Create `flake.nix` using the template above.

4. Generate Cargo.nix:
   ```bash
   nix develop -c crate2nix generate
   git add Cargo.nix
   ```

5. Verify:
   ```bash
   nix build
   nix run
   ```

## When to Use This vs rust-tool

| Use Case | Builder |
|----------|---------|
| Internal utility, single platform | **rust-binary** (this skill) |
| Public CLI tool with GitHub releases | `rust-tool` skill |
| Cross-platform distribution needed | `rust-tool` skill |

## Conventions

- **Cargo.nix** must be committed to git
- No standard lifecycle apps — add your own as needed
- Overlay exports `pkgs.{binary-name}` for consumption by other flakes
- Dev shell includes fenix toolchain, rust-analyzer, cargo-watch, cargo-edit
