---
name: rust-wasm
description: Scaffold a Rust WASM application using substrate's wasm-build helpers with Yew framework. Use when building a WebAssembly app with crate2nix, wasm-bindgen, wasm-opt, and nginx or Hanabi serving.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "rust"
    - "wasm"
    - "webassembly"
    - "yew"
    - "wasm-bindgen"
    - "frontend"
---

# Rust WASM — Substrate Builder

## Overview

Rust WebAssembly applications using the Yew framework. Build pipeline:
crate2nix (Rust compilation to wasm32-unknown-unknown) -> wasm-bindgen
(JS bindings) -> wasm-opt (optimization). Served via nginx or Hanabi (preferred).

Uses fenix for the wasm32-unknown-unknown Rust toolchain target.

**Builder:** `substrate/lib/wasm-build.nix`

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crate2nix.url = "github:nix-community/crate2nix";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
  };

  outputs = { self, nixpkgs, fenix, crate2nix, substrate, ... }:
    let
      systems = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          fenixPkgs = fenix.packages.${system};
          wasmBuild = import "${substrate}/lib/wasm-build.nix" {
            inherit pkgs crate2nix;
            fenix = fenixPkgs;
          };
        in f pkgs wasmBuild
      );
    in {
      packages = forEachSystem (pkgs: wasmBuild: {
        default = wasmBuild.mkWasmBuild {
          name = "{app-name}";
          src = ./.;
          # Optional:
          # cargoNix = ./Cargo.nix;
          # indexHtml = ./index.html;
          # staticAssets = ./static;
          # wasmBindgenTarget = "web";
          # optimizeLevel = 3;
          # crateOverrides = {};
        };

        dockerImage = wasmBuild.mkWasmDockerImage {
          name = "ghcr.io/pleme-io/{app-name}";
          wasmApp = self.packages.${system}.default;
          # Optional:
          # tag = "latest";
          # architecture = "amd64";
          # port = 80;
        };

        # Preferred: use Hanabi BFF server instead of nginx
        # dockerImageHanabi = wasmBuild.mkWasmDockerImageWithHanabi {
        #   name = "ghcr.io/pleme-io/{app-name}";
        #   wasmApp = self.packages.${system}.default;
        #   webServer = hanabi;  # Hanabi binary from crate2nix build
        # };
      });

      devShells = forEachSystem (pkgs: wasmBuild: {
        default = wasmBuild.mkWasmDevShell {
          name = "{app-name}";
          # Optional:
          # extraPackages = [];
        };
      });
    };
}
```

## Build Helpers

### `mkWasmBuild`

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Application name |
| `src` | yes | — | Source directory |
| `cargoNix` | no | `src + "/Cargo.nix"` | Path to generated Cargo.nix |
| `indexHtml` | no | `src + "/index.html"` | Path to index.html (auto-generated if missing) |
| `staticAssets` | no | `null` | Directory of static assets to copy |
| `wasmBindgenTarget` | no | `"web"` | wasm-bindgen target mode |
| `optimizeLevel` | no | `3` | wasm-opt optimization level (0-4) |
| `crateOverrides` | no | `{}` | Per-crate build overrides |

### `mkWasmDockerImage` (nginx)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Image name (e.g., `"ghcr.io/pleme-io/my-app"`) |
| `wasmApp` | yes | — | Built WASM application derivation |
| `tag` | no | `"latest"` | Image tag |
| `architecture` | no | `"amd64"` | Docker architecture |
| `port` | no | `80` | Nginx listening port |

### `mkWasmDockerImageWithHanabi` (preferred)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Image name |
| `wasmApp` | yes | — | Built WASM application derivation |
| `webServer` | yes | — | Hanabi binary from crate2nix build |
| `tag` | no | `"latest"` | Image tag |
| `architecture` | no | `"amd64"` | Docker architecture |

Hanabi provides: health checks (port 8080), gzip/brotli compression, CORS, WASM MIME types.

### `mkWasmDevShell`

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Application name |
| `extraPackages` | no | `[]` | Additional packages |

**Included tools:** fenix wasm toolchain, wasm-bindgen-cli, binaryen (wasm-opt), trunk, cargo-watch

## Build Pipeline

1. **crate2nix** compiles Rust to `wasm32-unknown-unknown`
2. **wasm-bindgen** generates JS bindings (`.js` + `_bg.wasm`)
3. **wasm-opt** optimizes the WASM binary (bulk-memory, threads)
4. **index.html** + static assets are assembled into the output

## WASM-Specific Rust Flags

```
CARGO_BUILD_TARGET = "wasm32-unknown-unknown"
RUSTFLAGS = "-C target-feature=+atomics,+bulk-memory,+mutable-globals"
```

## Docker Serving Options

### nginx (legacy)
- Serves static files on port 80
- WASM MIME type + CORS headers configured
- Gzip compression enabled

### Hanabi (preferred)
- Full-stack observability
- Health checks on port 8080
- Gzip + Brotli compression
- CORS configuration via YAML
- WASM-specific headers (COOP, COEP)
- Static file serving from `/app/static`

## Initial File Layout

```
{app-name}/
  flake.nix
  Cargo.toml
  Cargo.lock
  Cargo.nix          # Generated: crate2nix generate (commit to git)
  index.html
  src/
    main.rs           # or lib.rs for Yew app
  static/             # Optional static assets
    styles.css
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{app-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{app-name}.git
   cd {app-name}
   ```

2. Initialize Cargo project:
   ```bash
   cargo init --name {app-name}
   ```

3. Add Yew and WASM dependencies to `Cargo.toml`:
   ```toml
   [dependencies]
   yew = "0.21"
   wasm-bindgen = "0.2"
   web-sys = "0.3"
   ```

4. Create `index.html`:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
       <meta charset="utf-8">
       <title>{app-name}</title>
   </head>
   <body>
       <script type="module">
           import init from './{app-name}.js';
           init();
       </script>
   </body>
   </html>
   ```

5. Generate Cargo.nix:
   ```bash
   nix develop -c crate2nix generate
   git add Cargo.nix
   ```

6. Create `flake.nix` using the template above.

7. Verify:
   ```bash
   nix build .#default
   # Dev server:
   nix develop -c trunk serve
   ```

## Outputs

```nix
{
  packages.<system> = {
    default = <WASM build output (JS + WASM + HTML)>;
    dockerImage = <nginx Docker image>;
    # or:
    dockerImageHanabi = <Hanabi Docker image>;
  };
  devShells.<system>.default = <mkShell with wasm toolchain + trunk>;
}
```

## Conventions

- **Cargo.nix** must be committed to git
- Use `trunk serve` for local development with hot reload
- Prefer Hanabi over nginx for production serving (health checks, compression)
- WASM builds target `wasm32-unknown-unknown` exclusively
- Static assets go in `static/` directory

## Anti-Patterns

- Never skip wasm-opt — unoptimized WASM binaries are significantly larger
- Never use `wasmBindgenTarget = "bundler"` unless you have a JS bundler in the pipeline
- Never manually edit Cargo.nix — always regenerate via crate2nix
- Never serve WASM without proper MIME type (`application/wasm`) and CORS headers

## Examples

Existing apps using this pattern:
- Yew-based frontend applications in the nexus ecosystem
