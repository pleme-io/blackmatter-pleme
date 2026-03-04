---
name: ruby-gem
description: Scaffold a Ruby gem library using substrate's ruby-gem-flake builder with bundix/ruby-nix. Use when creating a Ruby gem with dev shell, test, bump, build, and push lifecycle.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-03-04"
  domain_keywords:
    - "ruby"
    - "gem"
    - "library"
    - "rubygems"
    - "bundix"
    - "ruby-nix"
---

# Ruby Gem — Substrate Builder

## Overview

Ruby gems with Nix-managed environments using bundix/ruby-nix. Provides a dev
shell with the gem environment and full SDLC lifecycle apps: test, regen
(gemset.nix), bump, build, push, and release. All gem operations delegate to
the `forge` CLI.

No Docker, no deploy — gems publish to RubyGems.org.

**Builder:** `substrate/lib/ruby-gem-flake.nix` (wraps `ruby-gem.nix`)
**Service builder:** `substrate/lib/ruby-build.nix` (gem SDLC apps)

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
    (import "${substrate}/lib/ruby-gem-flake.nix" {
      inherit nixpkgs ruby-nix flake-utils substrate forge;
    }) {
      inherit self;
      name = "{gem-name}";
      # Optional:
      # shellHookExtra = "";
      # devShellExtras = [];
    };
}
```

## Builder Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `name` | yes | — | Gem name |
| `self` | yes | — | Flake self reference |
| `shellHookExtra` | no | `""` | Additional shell hook commands |
| `devShellExtras` | no | `[]` | Additional packages for dev shell |
| `systems` | no | `["x86_64-linux" "aarch64-linux" "aarch64-darwin"]` | Target systems |

## Standard Apps

| App | Command | Description |
|-----|---------|-------------|
| `test` | `nix run .#test` | Run gem test suite via forge |
| `regen` | `nix run .#regen` | Regenerate `Gemfile.lock` and `gemset.nix` |
| `gem:bump` | `nix run .#gem:bump` | Version bump in `lib/*/version.rb` via forge |
| `gem:build` | `nix run .#gem:build` | Build `.gem` file from gemspec |
| `gem:push` | `nix run .#gem:push` | Build and push to RubyGems.org via forge |
| `gem:release` | `nix run .#gem:release` | Regen + push in one step |

## Initial File Layout

```
{gem-name}/
  flake.nix
  Gemfile
  Gemfile.lock
  gemset.nix          # Generated: bundix (commit to git)
  {gem-name}.gemspec
  lib/
    {gem-name}.rb
    {gem-name}/
      version.rb
  spec/
    spec_helper.rb
    {gem-name}_spec.rb
```

## Setup Steps

1. Create repo and clone:
   ```bash
   gh repo create pleme-io/{gem-name} --public
   cd ~/code/github/pleme-io && git clone git@github.com:pleme-io/{gem-name}.git
   cd {gem-name}
   ```

2. Initialize the gem:
   ```bash
   bundle gem {gem-name} --test=rspec
   ```

3. Generate `gemset.nix`:
   ```bash
   bundix
   git add gemset.nix
   ```

4. Create `flake.nix` using the template above.

5. Verify:
   ```bash
   nix develop -c bundle exec rspec
   nix run .#test
   ```

## Dev Shell

The dev shell includes:
- Ruby interpreter (from ruby-nix overlay)
- Gem environment with all bundled deps
- `RUBYLIB` set to `$PWD/lib`
- `DRY_TYPES_WARNINGS=false` (suppresses dry-types warnings)

## Regeneration

When dependencies change in `Gemfile`:

```bash
nix run .#regen
# or manually:
bundle lock --update
bundix
git add Gemfile.lock gemset.nix
```

## Conventions

- `gemset.nix` must be committed to git — ruby-nix reads it for environment setup
- `Gemfile.lock` must be committed to git
- All gem lifecycle operations (bump, build, push, test) go through `forge`
- Version is managed in `lib/{gem-name}/version.rb`
- Dev shell uses ruby-nix overlay for consistent Ruby version

## Anti-Patterns

- Never run `gem install` manually — use the Nix dev shell with bundled gems
- Never skip `gemset.nix` regeneration after changing `Gemfile`
- Never edit `gemset.nix` manually — always regenerate via `bundix` or `nix run .#regen`
- Never push without running tests first

## Examples

Existing gems using this pattern:
- `pangea-core` — platform core gem
