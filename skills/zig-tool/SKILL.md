---
name: zig-tool
description: Scaffold a cross-platform Zig CLI tool with GitHub releases using substrate's zig-tool-release builder. Use when creating a CLI tool with native Zig cross-compilation to all 4 targets on the host — no remote builders needed.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "zig"
    - "tool"
    - "cli"
    - "cross-compilation"
    - "release"
    - "github release"
---

# Zig Tool — Substrate Builder

## Overview

Cross-platform CLI tools with 4 build targets and GitHub releases.
Unlike Rust, Zig has built-in cross-compilation — ALL targets are built on the
host machine. No remote builders, no fenix, no crate2nix needed.
Linux targets use musl for fully static binaries.

**Builder:** `substrate/lib/zig-tool-release-flake.nix` (wraps `zig-tool-release.nix`)
**Overlay:** `substrate/lib/zig-overlay.nix` (via `mkZigOverlay`)

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
    (import "${substrate}/lib/zig-tool-release-flake.nix" {
      inherit nixpkgs;
    }) {
      toolName = "{tool-name}";
      src = self;
      repo = "pleme-io/{tool-name}";
      # Optional:
      # version = "0.1.0";
      # deps = ./build.zig.zon2nix-lock;
      # nativeBuildInputs = [];
      # zigBuildFlags = [];
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `toolName` | yes | — | Tool/binary name |
| `src` | yes | — | Source directory (`self`) |
| `repo` | yes | — | GitHub repo in `org/repo` format (for releases) |
| `version` | no | `"0.1.0"` | Version string |
| `deps` | no | `null` | zon2nix dependency lockfile |
| `nativeBuildInputs` | no | `[]` | Additional build dependencies |
| `zigBuildFlags` | no | `[]` | Extra flags passed to `zig build` |
| `systems` | no | `["aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux"]` | Host systems |

## Build Targets (4 platforms)

| Package Name | Zig Target | Notes |
|-------------|-----------|-------|
| `{tool}-aarch64-macos` | `aarch64-macos` | Native on M-series |
| `{tool}-x86_64-macos` | `x86_64-macos` | Cross-compiled on ARM |
| `{tool}-x86_64-linux-musl` | `x86_64-linux-musl` | Static binary |
| `{tool}-aarch64-linux-musl` | `aarch64-linux-musl` | Static binary |

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `default` | `nix run` | Run native binary |
| `release` | `nix run .#release` | Build all 4 targets, git tag, GitHub release with assets |
| `bump` | `nix run .#bump -- patch` | Version bump (major\|minor\|patch) |
| `check-all` | `nix run .#check-all` | Run Zig tests and checks |

## Initial File Layout

```
{tool-name}/
  flake.nix
  build.zig
  build.zig.zon
  src/
    main.zig
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{tool-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{tool-name}.git
   cd {tool-name}
   ```

2. Initialize Zig project:
   ```bash
   zig init
   ```

3. Create `flake.nix` using the template above.

4. If the project has dependencies (build.zig.zon), generate the lock:
   ```bash
   # Use zon2nix to generate the dependency lock
   zon2nix > build.zig.zon2nix-lock
   ```

5. Verify:
   ```bash
   nix run .#check-all
   nix build .#{tool-name}-aarch64-macos
   ```

## Outputs

```nix
{
  packages.<system> = {
    default = <native binary>;
    {tool-name} = <native binary>;
    {tool-name}-aarch64-macos = <arm64 macOS binary>;
    {tool-name}-x86_64-macos = <x86 macOS binary>;
    {tool-name}-x86_64-linux-musl = <static x86 Linux binary>;
    {tool-name}-aarch64-linux-musl = <static arm64 Linux binary>;
  };
  devShells.<system>.default = <mkShell with zigToolchain + zls>;
  apps.<system> = { default, release, bump, check-all };
  overlays.default = <exports pkgs.{tool-name}>;
}
```

## Cross-Compilation Advantages

- **No remote builders needed** — Zig bundles its own libc for all targets
- **All 4 binaries build on any host** — macOS ARM can build Linux musl binaries
- **Static Linux binaries** — musl linking produces fully portable executables
- **Darwin targets** — require building ON Darwin (macOS system headers needed)
- **Build time** — significantly faster than Rust cross-compilation

## Zig Build Flags

The build invokes:

```bash
zig build install \
  --system ${deps}         # Only if deps != null
  -Dtarget=${zigTarget}    # Cross-compilation target
  -Doptimize=ReleaseSafe   # Optimization level
  --color off              # No color in Nix builds
  ${zigBuildFlags}         # Custom flags
  --prefix $out            # Output directory
```

## Conventions

- Dev shell includes `zigToolchain` and `zls` (Zig language server)
- `ZIG_GLOBAL_CACHE_DIR` is set to `$TMPDIR/.zig-cache` during builds
- Native binary has no cross-compilation flag — uses host default
- Release workflow mirrors the Rust tool pattern (tag + GitHub release)

## Anti-Patterns

- Never use `--prefix "$out"` when the build uses `zig-out/` for resources — copy manually
- Never skip `-Doptimize=ReleaseSafe` for release builds
- Never set `dontFixup = false` — Zig binaries don't need Nix fixup phase

## Examples

Existing tools using this pattern:
- `z9s` — Zig CLI tool example
