---
name: pleme-flake-update
description: Propagate nix flake.lock updates across the pleme-io repository chain using tend.
allowed-tools: Bash, Read
metadata:
  version: "2.0.0"
  last_verified: "2026-02-28"
---

# Pleme-io Flake Update Chain

## Usage

```bash
# Preview the update chain (no changes made)
tend flake-update --changed <repo> --dry-run

# Execute the full chain
tend flake-update --changed <repo>
```

### Examples

```bash
# After pushing to blackmatter-nvim
tend flake-update --changed blackmatter-nvim

# After pushing to blackmatter-go
tend flake-update --changed blackmatter-go

# Preview only
tend flake-update --changed blackmatter-claude --dry-run
```

## What It Does

1. Reads `flake_deps` from `~/.config/tend/config.yaml`
2. Computes transitive dependents of the changed repo (BFS + topological sort)
3. For each affected repo in dependency order:
   - Runs `nix flake update <inputs>` (only inputs that changed upstream)
   - Commits `flake.lock` with `chore: update <inputs>`
   - Pushes to remote
4. Bails immediately on any failure

## Important Constraints

- `nix flake update` only updates `flake.lock` — it does NOT change SHA pins in `flake.nix` URLs
- SHA-pinned system inputs (nixpkgs, sops-nix, home-manager) require a manual coordinated upgrade
- `claude-code` is the only floating input — all other system inputs are SHA-pinned
- After the chain completes with `nix` as a target, apply changes: `nix run .#darwin-rebuild`

## Commit Message Convention

- Single input: `chore: update blackmatter-shell`
- Multiple: `chore: update blackmatter-nvim blackmatter-shell`
