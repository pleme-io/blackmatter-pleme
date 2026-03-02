---
name: rust-service
description: Scaffold a dockerized Rust microservice using substrate's rust-service-flake builder. Use when creating a new backend service with Docker images, GraphQL, database migrations, and Kubernetes deployment.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-01"
  domain_keywords:
    - "rust"
    - "service"
    - "microservice"
    - "docker"
    - "graphql"
    - "kubernetes"
    - "deploy"
---

# Rust Service — Substrate Builder

## Overview

Dockerized Rust microservices with multi-arch images, database migrations,
GraphQL schema extraction, and GitOps deployment to Kubernetes.

**Builder:** `substrate/lib/rust-service-flake.nix` (wraps `rust-service.nix`)

## flake.nix Template

### Standalone Service

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
    };
    forge = {
      url = "github:pleme-io/forge";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.fenix.follows = "fenix";
      inputs.substrate.follows = "substrate";
    };
    crate2nix.url = "github:nix-community/crate2nix";
  };

  outputs = { self, nixpkgs, substrate, forge, crate2nix, ... }:
    (import "${substrate}/lib/rust-service-flake.nix" {
      inherit nixpkgs substrate forge crate2nix;
    }) {
      inherit self;
      serviceName = "{service-name}";
      registry = "ghcr.io/pleme-io/{service-name}";
      packageName = "{service-name}";
      namespace = "{service-name}-system";
      architectures = ["amd64" "arm64"];
      # Optional:
      # ports = { graphql = 8080; health = 8081; metrics = 9090; };
      # productName = null;
      # buildInputs = [];
      # nativeBuildInputs = [];
      # enableAwsSdk = false;
      # extraDevInputs = [];
      # devEnvVars = {};
      # migrationsPath = src + "/migrations";
      # crateOverrides = {};
    };
}
```

### Monorepo Service (flake-parts)

For services in the nexus monorepo, use `monorepo-parts.nix`:

```nix
# nix/parts/my-service.nix
{ pkgs, substrateLib, self, ... }: let
  service = substrateLib.rustService {
    serviceName = "{service-name}";
    src = self + "/pkgs/platform/{service-name}";
    repoRoot = self;
    productName = null;
    namespace = "{service-name}-system";
    registry = "ghcr.io/pleme-io/{service-name}";
    packageName = "{service-name}";
    architectures = ["amd64" "arm64"];
  };
in {
  packages = service.packages;
  devShells = service.devShells;
  apps = service.apps;
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `serviceName` | yes | — | Service name |
| `self` | yes | — | Flake self reference |
| `src` | no | `self` | Source directory |
| `registry` | no | derived | Docker registry (e.g., `ghcr.io/pleme-io/hanabi`) |
| `registryBase` | no | — | Registry prefix (e.g., `ghcr.io/pleme-io`) |
| `packageName` | no | `serviceName` | Cargo crate name in workspace |
| `namespace` | no | derived | K8s namespace |
| `productName` | no | `null` | Product identifier (for monorepo grouping) |
| `architectures` | no | `["amd64"]` | Docker image architectures |
| `ports` | no | `{ graphql=8080; health=8081; metrics=9090; }` | Port mapping |
| `buildInputs` | no | `[]` | Additional build deps |
| `nativeBuildInputs` | no | `[]` | Additional native build deps |
| `enableAwsSdk` | no | `false` | Enable AWS SDK support |
| `extraDevInputs` | no | `[]` | Extra dev shell packages |
| `devEnvVars` | no | `{}` | Extra dev shell env vars |
| `migrationsPath` | no | `src + "/migrations"` | Path to sqlx migrations |
| `cargoNix` | no | `src + "/Cargo.nix"` | Path to generated Cargo.nix |
| `crateOverrides` | no | `{}` | Per-crate build overrides |
| `cluster` | no | `"staging"` | Target cluster |
| `serviceDirRelative` | no | — | Path from repo root (monorepo) |

## Default Build Dependencies

| Category | Packages |
|----------|----------|
| Build inputs | openssl, postgresql, sqlite |
| Native build inputs | pkg-config, cmake, perl |

## Default Dev Environment Variables

```
DATABASE_URL = "postgresql://{service}_test:test_password@localhost:5432/{service}_test"
REDIS_URL = "redis://localhost:6379"
RUST_LOG = "info,{service}=debug"
PROTOC = "${pkgs.protobuf}/bin/protoc"
```

## Port Convention

| Port | Default | Purpose |
|------|---------|---------|
| `graphql` | 8080 | Main GraphQL/HTTP endpoint |
| `health` | 8081 | Health check endpoint |
| `metrics` | 9090 | Prometheus metrics endpoint |

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `build` | `nix run .#build` | Build Docker images with crate2nix |
| `push` | `nix run .#push` | Push to GHCR and Attic cache |
| `push-image` | `nix run .#push-image` | Push pre-built amd64 image |
| `deploy` | `nix run .#deploy` | Deploy to Kubernetes via GitOps |
| `release` | `nix run .#release` | Build multi-arch, push, tag, GitHub release |
| `rollout` | `nix run .#rollout` | Monitor rollout status |
| `test` | `nix run .#test` | Run tests |
| `lint` | `nix run .#lint` | Run clippy |
| `fmt` | `nix run .#fmt` | Format code |
| `fmt-check` | `nix run .#fmt-check` | Check formatting |
| `extract-schema` | `nix run .#extract-schema` | Extract GraphQL schema |
| `update-cargo-nix` | `nix run .#update-cargo-nix` | Update Cargo.nix |
| `regenerate` | `nix run .#regenerate` | Regenerate Cargo.nix |
| `dev` | `nix run .#dev` | Start local dev (docker-compose) |
| `dev-down` | `nix run .#dev-down` | Stop local dev |
| `migrate` | `nix run .#migrate` | Run database migrations |
| `migrate-status` | `nix run .#migrate-status` | Check migration status |
| `migrate-add` | `nix run .#migrate-add` | Add new migration |
| `integration-test` | `nix run .#integration-test` | Run integration tests |
| `status` | `nix run .#status` | Check service status |

## Docker Image Details

- **Base:** Layered Nix image (not FROM scratch)
- **Architectures:** amd64 + arm64 (configurable)
- **User:** 65534:65534 (nobody)
- **Static linking:** musl on Linux targets
- **Migrations:** Copied to `/app/migrations` in image
- **Env vars in image:** `GIT_SHA`, `RUST_LOG`, `PORT`, `HEALTH_PORT`, `GRAPHQL_PORT`
- **Cross-compilation:** Remote builders handle Linux targets from macOS

## Registry Derivation Rules

1. If `registry` is set explicitly → use it
2. Else if `productName` and `registryBase` → `${registryBase}/${productName}-${serviceName}`
3. Test images always → `${registry}-test`

## Initial File Layout

```
{service-name}/
  Cargo.toml
  Cargo.lock
  Cargo.nix              # Generated: crate2nix generate (commit to git)
  flake.nix
  src/
    main.rs
    lib.rs
  migrations/            # sqlx migrations
    .keep
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{service-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{service-name}.git
   cd {service-name}
   ```

2. Initialize Cargo project:
   ```bash
   cargo init --name {service-name}
   mkdir -p migrations
   touch migrations/.keep
   ```

3. Add standard dependencies to `Cargo.toml`:
   ```toml
   [dependencies]
   axum = "0.8"
   async-graphql = "7"
   async-graphql-axum = "7"
   sqlx = { version = "0.8", features = ["runtime-tokio", "postgres", "migrate"] }
   tokio = { version = "1", features = ["full"] }
   tracing = "0.1"
   tracing-subscriber = "0.3"
   ```

4. Create `flake.nix` using the template above.

5. Generate Cargo.nix:
   ```bash
   nix develop -c crate2nix generate
   git add Cargo.nix
   ```

6. Verify:
   ```bash
   nix run .#check-all
   nix run .#build
   ```

## Common Crate Overrides

For `tonic-build` (gRPC):
```nix
crateOverrides = {
  tonic-build = oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.protobuf ];
    PROTOC = "${pkgs.protobuf}/bin/protoc";
  };
};
```

For `aws-lc-sys` (AWS SDK):
```nix
enableAwsSdk = true;  # Handles aws-lc-sys and ring overrides automatically
```

## Forge Integration

- **Attic cache:** `attic push nexus` caches build artifacts
- **GHCR registry:** Images pushed to `ghcr.io/pleme-io/{service-name}`
- **GitOps deploy:** Updates image tag in k8s repo, FluxCD reconciles

## Conventions

- **Cargo.nix** must be committed to git
- **Migrations** folder is required (even if empty — use `.keep`)
- Docker images are always built for Linux targets via remote builders
- Dev shells use host platform (e.g., aarch64-darwin)
- `GIT_SHA` is injected at runtime, not cached in the image

## Examples

Existing services using this pattern:
- `hanabi` — BFF gateway (`ports = { graphql = 80; health = 8080; metrics = 8080; }`)
- `shinka` — Database migration operator
- `kenshi` — Ephemeral testing operator
