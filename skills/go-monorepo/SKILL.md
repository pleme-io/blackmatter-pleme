---
name: go-monorepo
description: Scaffold multi-binary builds from a Go monorepo using substrate's mkGoMonorepoSource and mkGoMonorepoBinary. Use when building multiple binaries from a single Go repository like kubernetes/kubernetes.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "go"
    - "golang"
    - "monorepo"
    - "kubernetes"
    - "multi-binary"
    - "buildGoModule"
---

# Go Monorepo — Substrate Builder

## Overview

Multiple binaries from a single Go repository. Creates a shared source with
version ldflags, then builds individual binaries from it. Eliminates boilerplate
across 6+ near-identical binary definitions.

Extends the `mkGoTool` story: `mkGoTool` = one tool from one repo,
`mkGoMonorepoSource` = shared source for many binaries.

**Builder:** `substrate/lib/go-monorepo.nix` (via `mkGoMonorepoSource`)
**Binary builder:** `substrate/lib/go-monorepo-binary.nix` (via `mkGoMonorepoBinary`)
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
      mkGoMonorepoSource = (import "${substrate}/lib/go-monorepo.nix").mkGoMonorepoSource;
      mkGoMonorepoBinary = (import "${substrate}/lib/go-monorepo-binary.nix").mkGoMonorepoBinary;

      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (goOverlay.mkGoOverlay {}) ];
          };

          monoSrc = mkGoMonorepoSource pkgs {
            owner = "{owner}";
            repo = "{repo}";
            version = "{version}";
            srcHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            versionPackage = "{go-package-path}/version";
          };
        in f pkgs monoSrc
      );
    in {
      packages = forEachSystem (pkgs: monoSrc: {
        {binary-a} = mkGoMonorepoBinary pkgs monoSrc {
          pname = "{binary-a}";
          description = "Description of binary A";
        };
        {binary-b} = mkGoMonorepoBinary pkgs monoSrc {
          pname = "{binary-b}";
          description = "Description of binary B";
          completions = { install = true; command = "{binary-b}"; };
        };
      });
    };
}
```

## Source Factory Arguments (`mkGoMonorepoSource`)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `owner` | yes | — | GitHub owner (e.g., `"kubernetes"`) |
| `repo` | yes | — | GitHub repo name (e.g., `"kubernetes"`) |
| `version` | yes | — | Version string without "v" prefix (e.g., `"1.34.3"`) |
| `srcHash` | yes | — | SRI hash for the source tarball |
| `tag` | no | `"v${version}"` | Git tag to fetch |
| `versionPackage` | no | `null` | Go package path for `-X` ldflags version injection |
| `extraLdflags` | no | `[]` | Additional ldflags beyond `-s -w` and version injection |

## Binary Builder Arguments (`mkGoMonorepoBinary`)

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `pname` | yes | — | Binary/package name (e.g., `"kubelet"`) |
| `description` | yes | — | Package description for meta |
| `subPackages` | no | `["cmd/${pname}"]` | Go packages to build |
| `homepage` | no | `null` | URL for meta |
| `completions` | no | `null` | Shell completion config |
| `nativeBuildInputs` | no | `[]` | Additional build-time deps |
| `postInstall` | no | `""` | Additional post-install script |
| `platforms` | no | `lib.platforms.linux` | Supported platforms |

## Version Injection

When `versionPackage` is set, the source factory injects these ldflags:

```
-X {versionPackage}.gitVersion=v{version}
-X {versionPackage}.gitMajor={major}
-X {versionPackage}.gitMinor={minor}
-X {versionPackage}.gitTreeState=clean
-X {versionPackage}.buildDate=1970-01-01T00:00:00Z
```

## Returned Attrsets

`mkGoMonorepoSource` returns:

```nix
{
  version = "1.34.3";
  src = <fetchFromGitHub derivation>;
  ldflags = [ "-s" "-w" "-X ..." ... ];
}
```

`mkGoMonorepoBinary` returns a single derivation (the built binary).

## Initial File Layout

Typically consumed as an overlay — no source files needed:

```
flake.nix          # References upstream GitHub repo via fetchFromGitHub
```

## Setup Steps

1. Create flake.nix using the template above.

2. Determine the Go version package for ldflags injection:
   ```bash
   # Look at the upstream repo for the version package
   grep -r "var gitVersion" <repo-source>/
   ```

3. Get the source hash:
   ```bash
   nix-prefetch-url --unpack https://github.com/{owner}/{repo}/archive/refs/tags/v{version}.tar.gz
   ```

4. Build individual binaries:
   ```bash
   nix build .#{binary-a}
   nix build .#{binary-b}
   ```

## Conventions

- `vendorHash = null` is always set by `mkGoMonorepoBinary` — monorepos vendor deps in-tree
- `doCheck = false` is always set — monorepo tests need the full environment
- Platforms default to `lib.platforms.linux` (most monorepo binaries are server-side)
- Overlay names are prefixed `blackmatter-` (e.g., `pkgs.blackmatter-kubelet`)
- The source factory is evaluated once per system, shared across all binaries

## Anti-Patterns

- Never build the entire monorepo — always specify `subPackages` per binary
- Never set `vendorHash` to a non-null value for monorepo binaries
- Never duplicate the source fetch — use `mkGoMonorepoSource` once, pass to all `mkGoMonorepoBinary` calls

## Examples

Existing projects using this pattern:
- `blackmatter-kubernetes` — kubernetes/kubernetes monorepo (kubelet, kubeadm, kube-apiserver, kube-controller-manager, kube-scheduler, kube-proxy)
