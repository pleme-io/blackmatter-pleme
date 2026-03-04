---
name: ruby-service
description: Scaffold a dockerized Ruby service using substrate's ruby-build module. Use when creating a Ruby backend service with Docker images, registry push, and deployment via forge.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "ruby"
    - "service"
    - "docker"
    - "deploy"
    - "bundix"
    - "ruby-nix"
---

# Ruby Service — Substrate Builder

## Overview

Dockerized Ruby services with layered Nix images, registry push, and
deployment via forge. Uses bundix/ruby-nix for gem environments and
`dockerTools.buildLayeredImage` for container images.

**Builder:** `substrate/lib/ruby-build.nix` (via `mkRubyDockerImage`, `mkRubyServiceApps`)
**Gem env:** `substrate/lib/ruby-gem.nix` (via ruby-nix/bundix)

## flake.nix Template

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    ruby-nix = {
      url = "github:sagittaros/ruby-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    forge = {
      url = "github:pleme-io/forge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ruby-nix, flake-utils, substrate, forge, ... }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux" "aarch64-darwin"] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ruby-nix.overlays.ruby ];
        };
        rnix = ruby-nix.lib pkgs;
        rnix-env = rnix {
          name = "{service-name}";
          gemset = self + "/gemset.nix";
        };

        rubyBuild = import "${substrate}/lib/ruby-build.nix" {
          inherit pkgs;
          forgeCmd = "${forge.packages.${system}.default}/bin/forge";
          defaultGhcrToken = "";
        };
      in {
        packages = {
          default = rnix-env.env;

          dockerImage = rubyBuild.mkRubyDockerImage {
            rubyPackage = rnix-env.env;
            rubyEnv = rnix-env.env;
            ruby = rnix-env.ruby;
            name = "ghcr.io/pleme-io/{service-name}";
            tag = "latest";
            # Optional:
            # cmd = [ "${rnix-env.env}/bin/{service-name}" ];
            # env = [ "RAILS_ENV=production" ];
            # extraContents = [ pkgs.curl ];
            # exposedPorts = { "3000/tcp" = {}; };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ rnix-env.env rnix-env.ruby ];
          shellHook = ''
            export RUBYLIB=$PWD/lib:$RUBYLIB
          '';
        };

        apps = rubyBuild.mkRubyServiceApps {
          srcDir = self;
          flakePath = self;
          imageOutput = "dockerImage";
          registry = "ghcr.io/pleme-io/{service-name}";
          name = "{service-name}";
        };
      }
    );
}
```

## Docker Image Builder (`mkRubyDockerImage`)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `rubyPackage` | yes | — | Built Ruby package (from bundlerApp or stdenv) |
| `rubyEnv` | yes | — | Ruby environment with gems |
| `ruby` | yes | — | Ruby interpreter |
| `name` | yes | — | Image name (e.g., `"ghcr.io/pleme-io/my-service"`) |
| `tag` | no | `"latest"` | Image tag |
| `cmd` | no | auto | Container command |
| `env` | no | `[]` | Additional environment variables |
| `extraContents` | no | `[]` | Additional packages in image |
| `workingDir` | no | `"/"` | Container working directory |
| `exposedPorts` | no | `{}` | Exposed ports |

## Service Apps (`mkRubyServiceApps`)

| App | Command | Description |
|-----|---------|-------------|
| `regen:{name}` | `nix run .#regen:{name}` | Regenerate `Gemfile.lock` and `gemset.nix` |
| `push:{name}` | `nix run .#push:{name}` | Build Docker image and push to GHCR via forge |
| `release:{name}` | `nix run .#release:{name}` | Regen + push in one step |

## Docker Image Details

- **Base:** Layered Nix image (`dockerTools.buildLayeredImage`)
- **Contents:** Ruby package, gem env, Ruby interpreter, cacert, coreutils
- **User:** app user (created via `docker-helpers.nix`)
- **SSL:** cert bundle from `pkgs.cacert`
- **Tmp:** `/tmp` with mode 1777

## Initial File Layout

```
{service-name}/
  flake.nix
  Gemfile
  Gemfile.lock
  gemset.nix          # Generated: bundix (commit to git)
  config.ru           # For Rack-based services
  lib/
    {service-name}.rb
    {service-name}/
      version.rb
  spec/
    spec_helper.rb
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{service-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{service-name}.git
   cd {service-name}
   ```

2. Initialize Ruby project:
   ```bash
   bundle init
   # Add dependencies to Gemfile
   bundle install
   ```

3. Generate `gemset.nix`:
   ```bash
   bundix
   git add gemset.nix
   ```

4. Create `flake.nix` using the template above.

5. Verify:
   ```bash
   nix build .#dockerImage
   docker load < result
   docker run --rm ghcr.io/pleme-io/{service-name}:latest
   ```

## Push Workflow

`nix run .#push:{service-name}` performs:

1. Builds Docker image via `nix build .#{imageOutput}`
2. Pushes to GHCR via `forge push` with auto-tags and retries
3. Requires `GITHUB_TOKEN` or `GHCR_TOKEN` (or `~/.config/github/token`)

## Conventions

- `gemset.nix` must be committed to git
- `Gemfile.lock` must be committed to git
- Docker images use layered builds for efficient caching
- GHCR authentication via `GITHUB_TOKEN` env var
- All push/release operations go through `forge`

## Anti-Patterns

- Never use `FROM ruby:X` Dockerfiles — use Nix layered images instead
- Never skip `gemset.nix` regeneration after changing `Gemfile`
- Never push without `GITHUB_TOKEN` set — the push will fail silently
- Never run `gem install` in the container — all deps are baked in at build time

## Examples

Existing services using this pattern:
- Ruby backend services in the pleme-io ecosystem
