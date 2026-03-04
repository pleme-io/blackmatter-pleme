---
name: typescript-library
description: Scaffold a TypeScript npm library using substrate's typescript-library-flake builder with dream2nix. Use when creating an npm package with build verification, version bumping, and npm publishing lifecycle.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "typescript"
    - "npm"
    - "library"
    - "package"
    - "dream2nix"
    - "publish"
---

# TypeScript Library — Substrate Builder

## Overview

TypeScript libraries that publish to npm. Uses dream2nix for dependency resolution
from `package-lock.json`. Provides build verification in the Nix sandbox, dev shells,
and full lifecycle apps (check-all, bump, publish, release).

No Docker, no deploy, no Kubernetes — libraries publish to npm only.

**Builder:** `substrate/lib/typescript-library-flake.nix` (wraps `typescript-library.nix`)

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    dream2nix.url = "github:nix-community/dream2nix";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, dream2nix, substrate, ... }:
    (import "${substrate}/lib/typescript-library-flake.nix" {
      inherit nixpkgs dream2nix substrate;
    }) {
      inherit self;
      name = "{library-name}";
      # Optional:
      # version = "1.0.0";
      # nodeVersion = pkgs.nodejs_22;
      # buildScript = "build";
      # extraDevInputs = [];
      # extraNativeBuildInputs = [];
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Library package name (e.g., `"pleme-types"`) |
| `self` | yes | — | Flake self reference (source directory) |
| `version` | no | `"1.0.0"` | Package version |
| `nodeVersion` | no | `nodejs_22` | Node.js version |
| `buildScript` | no | `"build"` | npm build script name |
| `extraDevInputs` | no | `[]` | Extra packages for dev shell |
| `extraNativeBuildInputs` | no | `[]` | Extra native build deps |
| `systems` | no | `["x86_64-linux" "aarch64-linux" "aarch64-darwin"]` | Target systems |

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `check-all` | `nix run .#check-all` | `biome check` + `tsc --noEmit` + `vitest run` |
| `bump` | `nix run .#bump -- patch` | Version bump (major\|minor\|patch), update package-lock.json, git commit + tag |
| `publish` | `nix run .#publish` | Build + `npm publish --access public` (requires `NPM_TOKEN`) |
| `release` | `nix run .#release -- patch` | Bump + build + publish + git push in one step |

## Initial File Layout

```
{library-name}/
  flake.nix
  package.json
  package-lock.json
  tsconfig.json
  src/
    index.ts
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{library-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{library-name}.git
   cd {library-name}
   ```

2. Initialize the project:
   ```bash
   npm init -y --scope=@pleme
   npx tsc --init
   mkdir -p src && echo "export {};" > src/index.ts
   ```

3. Add build tooling to `package.json`:
   ```json
   {
     "scripts": {
       "build": "tsc",
       "test": "vitest run",
       "check": "biome check src"
     },
     "devDependencies": {
       "typescript": "^5.7",
       "vitest": "^3.0",
       "@biomejs/biome": "^1.9"
     }
   }
   ```

4. Install and generate lock file:
   ```bash
   npm install
   ```

5. Create `flake.nix` using the template above.

6. Verify:
   ```bash
   nix run .#check-all
   nix build .#default
   ```

## Outputs

```nix
{
  packages.<system>.default = <dream2nix build output (dist/)>;
  devShells.<system>.default = <mkShell with nodejs + biome>;
  apps.<system> = { check-all, bump, publish, release };
}
```

## dream2nix Integration

The builder uses `nodejs-package-lock-v3` and `nodejs-granular-v3` dream2nix modules:

- Dependencies are resolved from `package-lock.json`
- Build runs `npm run {buildScript}` in the Nix sandbox
- Install copies `dist/`, `package.json`, and `README.md` to the output

## Conventions

- `package-lock.json` must be committed to git — dream2nix reads it for dep resolution
- `NPM_TOKEN` must be set for `publish` and `release` apps
- Version bumps update both `package.json` and `package-lock.json`
- Dev shell includes Node.js and biome (linter/formatter)
- Build script defaults to `"build"` — override with `buildScript` if different

## Anti-Patterns

- Never skip `package-lock.json` — dream2nix requires it for reproducible builds
- Never publish without running `check-all` first
- Never use `pnpm-lock.yaml` — this builder uses npm lockfile format
- Never manually edit version in `package-lock.json` — the bump app handles both files

## Examples

Existing libraries using this pattern:
- `@pleme/types` — shared TypeScript types
- `@pleme/ui-components` — shared UI components
