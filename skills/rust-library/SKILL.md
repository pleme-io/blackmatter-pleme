---
name: rust-library
description: Scaffold a new Rust crates.io library using substrate's rust-library.nix builder. Use when creating a new Rust library crate, setting up library CI/CD, or understanding the standard library flake.nix template.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-01"
  domain_keywords:
    - "rust"
    - "library"
    - "crate"
    - "crates.io"
    - "publish"
---

# Rust Library — Substrate Builder

## Overview

Libraries publish to crates.io. No Docker, no deploy, no Kubernetes.

**Builder:** `substrate/lib/rust-library.nix`

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
          rustLibrary = import "${substrate}/lib/rust-library.nix" {
            inherit system nixpkgs;
            nixLib = substrate;
            inherit crate2nix;
          };
          result = rustLibrary {
            name = "{library-name}";
            src = ./.;
            # Optional overrides:
            # buildInputs = [];
            # nativeBuildInputs = [];
            # crateOverrides = {};
            # extraDevInputs = [];
            # devEnvVars = {};
          };
        in f result
      );
    in {
      packages = forEachSystem (r: r.packages);
      devShells = forEachSystem (r: r.devShells);
      apps = forEachSystem (r: r.apps);
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Library crate name |
| `src` | yes | — | Source directory (`./.`) |
| `cargoNix` | no | `src + "/Cargo.nix"` | Path to generated Cargo.nix |
| `buildInputs` | no | `[]` | Additional build dependencies |
| `nativeBuildInputs` | no | `[]` | Additional native build dependencies |
| `crateOverrides` | no | `{}` | Per-crate build overrides |
| `extraDevInputs` | no | `[]` | Extra packages for dev shell |
| `devEnvVars` | no | `{}` | Extra env vars for dev shell |

**Default build inputs:** `openssl`
**Default native build inputs:** `pkg-config`

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `check-all` | `nix run .#check-all` | `cargo fmt --check` + `cargo clippy` + `cargo test` |
| `bump` | `nix run .#bump -- patch` | Version bump (patch\|minor\|major), regenerate Cargo.nix, git commit + tag |
| `publish` | `nix run .#publish` | Publish to crates.io (requires `CARGO_REGISTRY_TOKEN`) |
| `release` | `nix run .#release -- patch` | Bump + publish + push in one step |
| `regenerate` | `nix run .#regenerate` | Regenerate Cargo.nix from Cargo.lock |

## Initial File Layout

```
{library-name}/
  Cargo.toml
  Cargo.lock
  Cargo.nix          # Generated: crate2nix generate (commit to git)
  flake.nix
  src/
    lib.rs
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{library-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{library-name}.git
   cd {library-name}
   ```

2. Initialize Cargo project:
   ```bash
   cargo init --lib --name {library-name}
   ```

3. Create `flake.nix` using the template above.

4. Generate Cargo.nix:
   ```bash
   nix develop -c crate2nix generate
   git add Cargo.nix
   ```

5. Verify:
   ```bash
   nix run .#check-all
   ```

## Conventions

- **Cargo.nix** must be committed to git — crate2nix generates it once, then it's checked in
- **CARGO_REGISTRY_TOKEN** must be set for `publish` and `release` apps
- **Version bumps** regenerate Cargo.nix automatically
- Libraries use lighter deps than services (no postgres, sqlite, cmake, perl)
- Dev shell includes: fenixRustToolchain, rust-analyzer, cargo-watch, cargo-edit, crate2nix

## Anti-Patterns

- Never skip committing Cargo.nix — the Nix sandbox needs it
- Never publish without running `check-all` first
- Never manually edit Cargo.nix — always regenerate via `nix run .#regenerate`
