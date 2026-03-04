---
name: go-tool
description: Scaffold a Go CLI tool using substrate's mkGoTool builder with Go overlay. Use when building a single Go CLI tool from upstream source with vendorHash, ldflags version injection, and shell completions.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "go"
    - "golang"
    - "tool"
    - "cli"
    - "buildGoModule"
    - "go overlay"
---

# Go Tool — Substrate Builder

## Overview

Single Go CLI tool built from upstream source using `buildGoModule`.
Uses substrate's Go overlay (Go 1.25 from source) for consistent toolchain.
Supports ldflags version injection, shell completions (bash/zsh/fish), and
standard meta attributes.

**Builder:** `substrate/lib/go-tool.nix` (via `mkGoTool`)
**Overlay:** `substrate/lib/go-overlay.nix` (via `mkGoOverlay`)

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, substrate, ... }:
    let
      goOverlay = import "${substrate}/lib/go-overlay.nix";
      goToolBuilder = import "${substrate}/lib/go-tool.nix";

      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (goOverlay.mkGoOverlay {}) ];
          };
        in f pkgs
      );
    in {
      packages = forEachSystem (pkgs: {
        default = goToolBuilder.mkGoTool pkgs {
          pname = "{tool-name}";
          version = "1.0.0";
          src = pkgs.fetchFromGitHub {
            owner = "{owner}";
            repo = "{tool-name}";
            tag = "v1.0.0";
            hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          };
          vendorHash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
          # Optional:
          # subPackages = [ "cmd/{tool-name}" ];
          # versionLdflags = { "main.version" = "1.0.0"; };
          # completions = { install = true; command = "{tool-name}"; };
          description = "{tool-name} - Go CLI tool";
        };
      });

      overlays.default = goToolBuilder.mkGoToolOverlay {
        "{tool-name}" = {
          pname = "{tool-name}";
          version = "1.0.0";
          src = self;
          vendorHash = "sha256-...";
        };
      };
    };
}
```

## Builder Arguments (`mkGoTool`)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `pname` | yes | — | Package/binary name |
| `version` | yes | — | Version string (without "v" prefix) |
| `src` | yes | — | Source derivation (`fetchFromGitHub`, etc.) |
| `vendorHash` | yes | — | Hash for Go module deps (`null` if vendored in-tree) |
| `subPackages` | no | all | Go packages to build |
| `ldflags` | no | `["-s" "-w"]` | Explicit ldflags (overrides `versionLdflags`) |
| `versionLdflags` | no | `{}` | Attrset of `-X` ldflags for version injection |
| `tags` | no | `[]` | Go build tags (e.g., `["netcgo"]`) |
| `proxyVendor` | no | `false` | Use proxy vendor mode |
| `modRoot` | no | `null` | Go module root within source (for monorepos) |
| `doCheck` | no | `false` | Run tests during build |
| `completions` | no | `null` | Shell completion config |
| `extraBuildInputs` | no | `[]` | Additional nativeBuildInputs |
| `extraPostInstall` | no | `""` | Additional postInstall script |
| `extraAttrs` | no | `{}` | Extra attrs passed to `buildGoModule` |
| `description` | no | auto | Package description for meta |
| `homepage` | no | `null` | Package homepage URL |
| `license` | no | `asl20` | License |
| `platforms` | no | `lib.platforms.all` | Supported platforms |

## Shell Completions

Two completion modes:

```nix
# Mode 1: Binary supports `completion {bash,zsh,fish}` subcommand
completions = { install = true; command = "helm"; };

# Mode 2: Completion scripts in source tree
completions = { install = true; fromSource = "completion"; };
```

## Overlay Helper (`mkGoToolOverlay`)

Creates an overlay providing multiple Go tools:

```nix
overlays.default = goToolBuilder.mkGoToolOverlay {
  blackmatter-stern = { pname = "stern"; version = "1.31.0"; ... };
  blackmatter-kubectl-tree = { pname = "kubectl-tree"; version = "0.4.6"; ... };
};
# Provides: pkgs.blackmatter-stern, pkgs.blackmatter-kubectl-tree
```

## Go Overlay

The Go overlay ensures all tools use the same Go version (1.25 from source):

```nix
overlays = [ (goOverlay.mkGoOverlay {}) ];
# Provides: pkgs.goToolchain, pkgs.go, pkgs.buildGoModule
```

## Initial File Layout

For a standalone Go tool repo:

```
{tool-name}/
  flake.nix
  go.mod
  go.sum
  main.go
  # or:
  cmd/
    {tool-name}/
      main.go
```

For tools built from upstream (typical pattern):

```
# No source files needed — src comes from fetchFromGitHub
# The flake.nix IS the whole project
flake.nix
```

## Setup Steps

1. Create flake.nix using the template above.

2. Get the source hash:
   ```bash
   nix-prefetch-url --unpack https://github.com/{owner}/{tool-name}/archive/refs/tags/v{version}.tar.gz
   ```

3. Get the vendor hash (build will fail and print the correct hash):
   ```bash
   nix build .#default 2>&1 | grep "got:"
   ```

4. Verify:
   ```bash
   nix build .#default
   nix run .#default -- --version
   ```

## Outputs

```nix
{
  packages.<system> = {
    default = <Go binary>;
    {tool-name} = <Go binary>;
  };
  overlays.default = <exports pkgs.{tool-name} or pkgs.blackmatter-{tool-name}>;
}
```

## Conventions

- Use the Go overlay (`mkGoOverlay`) for consistent Go version across all tools
- Set `vendorHash = null` when deps are vendored in-tree (`vendor/` directory)
- Use `versionLdflags` for `-X main.version` style injection (cleaner than raw `ldflags`)
- Overlay tool names are prefixed `blackmatter-` (e.g., `pkgs.blackmatter-helm`)
- Module defaults use `(blackmatter-helm or kubernetes-helm)` fallback for overlay-free use

## Anti-Patterns

- Never override `pkgs.go` directly — use the overlay which handles `buildGoModule` too
- Never set `doCheck = true` for K8s tools — they need a running cluster for tests
- Never use `pkgs.buildGoModule.override` — causes infinite recursion; use `prev.callPackage` pattern

## Examples

Existing tools using this pattern:
- `blackmatter-kubernetes` — 22 K8s CLI tools (kubectl, helm, k9s, fluxcd, stern, etc.)
- `blackmatter-go` — Go toolchain consumer
