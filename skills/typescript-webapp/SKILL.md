---
name: typescript-webapp
description: Scaffold a Vite/React web application using substrate's web-build helpers. Use when creating a web frontend with Nix-based builds, Docker serving, and standardized dev shells.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "typescript"
    - "react"
    - "vite"
    - "webapp"
    - "frontend"
    - "docker"
    - "web"
---

# TypeScript Web App — Substrate Builder

## Overview

Vite/React web applications with Nix-based builds, Docker images for serving,
and standardized dev shells. Two build strategies: `mkViteBuild` (using
`buildNpmPackage` with hash-locked deps) or `mkDream2nixBuild` (using dream2nix
for automatic resolution from `package-lock.json`).

**Builder:** `substrate/lib/web-build.nix`

## flake.nix Template

### Using `mkViteBuild` (hash-locked)

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
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          webBuild = import "${substrate}/lib/web-build.nix" { inherit pkgs; };
        in f pkgs webBuild
      );
    in {
      packages = forEachSystem (pkgs: webBuild: {
        default = webBuild.mkViteBuild {
          appName = "{app-name}";
          src = ./.;
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          # Optional:
          # buildScript = "build:staging";
          # nodeVersion = pkgs.nodejs_20;
          # npmFlags = [];
        };
      });

      devShells = forEachSystem (pkgs: webBuild: {
        default = webBuild.mkWebDevShell {
          appName = "{app-name}";
          # Optional:
          # productName = "{app-name}";
          # extraPackages = [];
        };
      });
    };
}
```

### Using `mkDream2nixBuild` (dream2nix)

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
    let
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          webBuild = import "${substrate}/lib/web-build.nix" { inherit pkgs; };
        in f pkgs webBuild
      );
    in {
      packages = forEachSystem (pkgs: webBuild: {
        default = webBuild.mkDream2nixBuild {
          appName = "{app-name}";
          src = ./.;
          inherit dream2nix;
          # Optional:
          # buildScript = "build:staging";
          # version = "1.0.0";
          # npmFlags = ["--legacy-peer-deps"];
        };
      });
    };
}
```

## Build Helpers

### `mkViteBuild`

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `appName` | yes | — | Application name |
| `src` | yes | — | Source directory |
| `npmDepsHash` | yes | — | Hash for npm dependencies |
| `buildScript` | no | `"build:staging"` | npm build script |
| `nodeVersion` | no | `nodejs_20` | Node.js version |
| `npmFlags` | no | `[]` | Additional npm flags |

**Default build deps:** cairo, pango, pixman, libjpeg, giflib, librsvg (for canvas/image processing)

### `mkDream2nixBuild`

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `appName` | yes | — | Application name |
| `src` | yes | — | Source directory |
| `dream2nix` | yes | — | dream2nix flake input |
| `buildScript` | no | `"build:staging"` | npm build script |
| `version` | no | `"1.0.0"` | Package version |
| `nodeVersion` | no | `nodejs_20` | Node.js version |
| `npmFlags` | no | `["--legacy-peer-deps"]` | npm flags |
| `packageLockFile` | no | `"${src}/package-lock.json"` | Path to lockfile |

### `mkWebDevShell`

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `appName` | yes | — | Application name |
| `productName` | no | `appName` | Display name in shell banner |
| `extraPackages` | no | `[]` | Additional packages |
| `nodeVersion` | no | `nodejs_20` | Node.js version |

**Included tools:** git, node, pnpm, npm, typescript, TS language server, playwright, docker, docker-compose, skopeo, kubectl, helm, k9s, fluxcd, jq, yq, curl

### `mkWebPackages`

Generates standard package outputs:

```nix
mkWebPackages {
  appName = "{app-name}";
  builtApp = viteApp;
  dockerImages = { dockerImage-amd64 = ...; };
}
# Returns: { default, {app-name}, viteApp, dockerImage-amd64 }
```

### `mkWebLocalApps`

Generates local testing apps:

```nix
mkWebLocalApps {
  appName = "{app-name}";
  # Optional:
  # flakeAttr = "dockerImage-amd64";
  # port = 8080;
}
# Returns: { local, local-down }
```

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `local` | `nix run .#local` | Build Docker image, load, and run locally |
| `local-down` | `nix run .#local-down` | Stop local container |

## Initial File Layout

```
{app-name}/
  flake.nix
  package.json
  package-lock.json
  tsconfig.json
  vite.config.ts
  index.html
  src/
    App.tsx
    main.tsx
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{app-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{app-name}.git
   cd {app-name}
   ```

2. Initialize Vite project:
   ```bash
   npm create vite@latest . -- --template react-ts
   npm install
   ```

3. Create `flake.nix` using one of the templates above.

4. Get the npm deps hash (for `mkViteBuild`):
   ```bash
   nix build .#default 2>&1 | grep "got:"
   ```

5. Verify:
   ```bash
   nix build .#default
   ```

## Outputs

```nix
{
  packages.<system> = {
    default = <Vite build output (dist/)>;
    {app-name} = <same>;
    viteApp = <same>;
    # If Docker images configured:
    dockerImage-amd64 = <Docker image>;
  };
  devShells.<system>.default = <mkShell with full web dev tooling>;
  apps.<system> = { local, local-down };
}
```

## Conventions

- `package-lock.json` must be committed to git
- Build output is the `dist/` directory (standard Vite output)
- `NODE_ENV=production` and `VITE_ENV=staging` are set during build
- Dev shell sets `NODE_ENV=development` and adds `node_modules/.bin` to PATH
- Docker images serve the built app with nginx on port 80

## Anti-Patterns

- Never use `pnpm-lock.yaml` with `mkViteBuild` — it uses npm lockfile
- Never skip the `--legacy-peer-deps` flag with dream2nix when React 18+ deps conflict
- Never commit `node_modules/` — deps are managed by Nix during build

## Examples

Existing apps using this pattern:
- `lilitu` — dating classifieds platform frontend (React + MUI v7)
