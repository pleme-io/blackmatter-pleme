---
name: rust-tool
description: Scaffold a cross-platform Rust CLI tool with GitHub releases using substrate's rust-tool-release builder. Use when creating a CLI tool that needs multi-platform binaries and automated GitHub releases.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-01"
  domain_keywords:
    - "rust"
    - "tool"
    - "cli"
    - "release"
    - "cross-platform"
    - "github release"
---

# Rust Tool — Substrate Builder

## Overview

Cross-platform CLI tools with 4 build targets and GitHub releases.
Static linking on Linux (musl), remote builders for cross-compilation from macOS.

**Builder:** `substrate/lib/rust-tool-release-flake.nix` (wraps `rust-tool-release.nix`)

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    crate2nix.url = "github:nix-community/crate2nix";
    flake-utils.url = "github:numtide/flake-utils";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, crate2nix, flake-utils, substrate, ... }:
    (import "${substrate}/lib/rust-tool-release-flake.nix" {
      inherit nixpkgs crate2nix flake-utils;
    }) {
      toolName = "{tool-name}";
      src = self;
      repo = "pleme-io/{tool-name}";
      # Optional:
      # buildInputs = [];
      # crateOverrides = {};
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `toolName` | yes | — | Tool/binary name |
| `src` | yes | — | Source directory (`self`) |
| `repo` | yes | — | GitHub repo in `org/repo` format (for releases) |
| `cargoNix` | no | `src + "/Cargo.nix"` | Path to generated Cargo.nix |
| `buildInputs` | no | `[]` | Additional build dependencies |
| `crateOverrides` | no | `{}` | Per-crate build overrides |
| `systems` | no | `["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"]` | Host systems |

## Build Targets (4 platforms)

| Package Name | Platform | Notes |
|-------------|----------|-------|
| `{tool}-aarch64-apple-darwin` | macOS ARM64 | Native on M-series |
| `{tool}-x86_64-apple-darwin` | macOS Intel | Rosetta on ARM |
| `{tool}-x86_64-unknown-linux-musl` | Linux x86_64 | Static binary, remote builder |
| `{tool}-aarch64-unknown-linux-musl` | Linux ARM64 | Static binary, remote builder |

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `default` | `nix run` | Run native binary |
| `release` | `nix run .#release` | Build all 4 targets → git tag → GitHub release with assets |
| `bump` | `nix run .#bump -- patch` | Version bump (major\|minor\|patch) |
| `regenerate-cargo-nix` | `nix run .#regenerate-cargo-nix` | Regenerate Cargo.nix |
| `check-all` | `nix run .#check-all` | `cargo fmt --check` + `cargo clippy` + `cargo test` |

## Release Workflow

`nix run .#release` performs:

1. Reads version from `Cargo.toml`
2. Creates git tag `v{version}`
3. Builds all 4 platform binaries
4. Creates GitHub release with binaries as assets
5. Pushes tag to origin

**Prerequisite:** Run `nix run .#bump` first to set the version.

## Initial File Layout

```
{tool-name}/
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
   gh repo create pleme-io/{tool-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{tool-name}.git
   cd {tool-name}
   ```

2. Initialize Cargo project:
   ```bash
   cargo init --name {tool-name}
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
   nix build .#{tool-name}-aarch64-apple-darwin
   ```

## Outputs

```nix
{
  packages.<system> = {
    default = <native binary>;
    {tool-name} = <native binary>;
    {tool-name}-aarch64-apple-darwin = <arm64 macOS binary>;
    {tool-name}-x86_64-apple-darwin = <x86 macOS binary>;
    {tool-name}-x86_64-unknown-linux-musl = <static x86 Linux binary>;
    {tool-name}-aarch64-unknown-linux-musl = <static arm64 Linux binary>;
  };
  devShells.<system>.default = <dev shell with fenix toolchain>;
  apps.<system> = { default, release, bump, regenerate-cargo-nix, check-all };
  overlays.default = <exports pkgs.{tool-name}>;
}
```

## Cross-Compilation Notes

- Linux targets use musl for fully static binaries (no glibc dependency)
- Cross-compilation from macOS requires remote builders configured in `/etc/nix/machines`
- The `nix-rosetta-builder` handles x86_64-linux builds on ARM Macs via Rosetta 2
- macOS x86_64 target uses Rosetta when building on ARM

## Conventions

- **Cargo.nix** must be committed to git
- **`repo`** argument is required for GitHub release creation
- Version is read from `Cargo.toml` — always bump before releasing
- The overlay exports `pkgs.{tool-name}` for consumption by nix flakes

## Examples

Existing tools using this pattern:
- `tend` — workspace repository manager
- `codesearch` — semantic code search
- `zoekt-mcp` — Zoekt MCP server
- `umbra` — Kubernetes diagnostic MCP
