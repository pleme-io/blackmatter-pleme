---
name: workspace-management
description: Manage the pleme-io workspace — add repos, configure Zoekt/Codesearch indexing, expand tend config, add new orgs, and maintain the CLAUDE.md hierarchy. Use when onboarding new repos, setting up indexing for new projects, or expanding the workspace structure.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-02-27"
  domain_keywords:
    - "workspace"
    - "zoekt"
    - "codesearch"
    - "index"
    - "tend"
    - "repo"
    - "org"
---

# Workspace Management

## Workspace Structure

```
~/code/${git-service}/${org-or-user}/${repo}
```

Currently:
```
~/code/github/
  pleme-io/   ← primary (100+ repos, all indexed)
  drzln/      ← personal
  binti-family/
```

Configuration is declarative — all workspace state lives in `nix/nodes/cid/default.nix`
and deploys via `home-manager` on rebuild.

## Adding a New Repo to the Workspace

When a new repo is created in the pleme-io org:

### 1. Tend auto-discovers it

If `discover: true` is set (it is for pleme-io), `tend sync` picks it up automatically.
No config change needed for discovery.

### 2. Add to Zoekt indexing

Edit `nix/nodes/cid/default.nix`, find the `services.zoekt.daemon.repos` list,
and add the new repo path:

```nix
services.zoekt.daemon = {
  enable = true;
  repos = let base = "~/code/github/pleme-io"; in [
    # ... existing repos ...
    "${base}/new-repo"    # ← add here
  ];
};
```

Zoekt indexes trigram patterns for instant exact-match search.

### 3. Codesearch auto-discovers

Codesearch is configured with `kind = "org"` for pleme-io, so it auto-discovers
repos via the GitHub API. No manual addition needed unless you want to index
repos from outside the org.

### 4. Rebuild

```bash
cd ~/code/github/pleme-io/nix && nix run .#darwin-rebuild
```

## Adding a New Org

### 1. Create directory

```bash
mkdir -p ~/code/github/new-org
```

### 2. Add tend workspace

Edit `nix/nodes/cid/default.nix`, find the `home.file.".config/tend/config.yaml"` block
and add a new workspace:

```yaml
- name: new-org
  provider: github
  base_dir: ~/code/github/new-org
  clone_method: ssh
  discover: true
  org: new-org
  exclude: []
  extra_repos: []
```

### 3. Add Zoekt repos (if needed)

Add entries to `services.zoekt.daemon.repos` for repos you want trigram-indexed.

### 4. Add Codesearch source (if needed)

Add a new source entry to `services.codesearch.daemon.github.sources`:

```nix
{
  owner = "new-org";
  kind = "org";
  cloneBase = "~/code/github/new-org";
  skipArchived = true;
  skipForks = false;
}
```

### 5. Optionally add CLAUDE.md

Create `nix/nodes/cid/new-org-CLAUDE.md` and deploy via `home.file`:

```nix
home.file."code/github/new-org/CLAUDE.md".source = ./new-org-CLAUDE.md;
```

### 6. Optionally add .envrc

```nix
home.file."code/github/new-org/.envrc".text = "use_tend\n";
```

After rebuild, run `direnv allow ~/code/github/new-org/.envrc` once.

### 7. Rebuild

```bash
cd ~/code/github/pleme-io/nix && nix run .#darwin-rebuild
```

## CLAUDE.md Hierarchy

Each level provides progressively more specific guidance:

| File | Deployed From | Content |
|------|--------------|---------|
| `~/code/CLAUDE.md` | `nix/nodes/cid/workspace-CLAUDE.md` | Directory convention, how to add services/orgs |
| `~/code/github/CLAUDE.md` | `nix/nodes/cid/github-CLAUDE.md` | GitHub-specific conventions, current orgs |
| `~/code/github/pleme-io/CLAUDE.md` | `nix/nodes/cid/pleme-io-CLAUDE.md` | Full repo map, architecture, contribution guide |

To update any CLAUDE.md, edit the source file in the nix repo and rebuild.
Do NOT edit the deployed symlinks directly.

## Nix Integration for New Tools

When adding a new tool repo that should be available as a package:

### 1. Add as flake input

Edit `nix/flake.nix`:

```nix
new-tool = {
  url = "github:pleme-io/new-tool";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### 2. Add to home.packages

Edit `nix/nodes/cid/default.nix`:

```nix
home.packages = [
  # ... existing packages ...
  pkgs.new-tool
];
```

Or if it's from a flake input:

```nix
home.packages = [
  inputs.new-tool.packages.${pkgs.system}.default
];
```

### 3. Add overlays if needed

If the tool needs to be available as `pkgs.new-tool`, add it to the overlay
in `nix/overlays/`.

## Key Files

| File | Purpose |
|------|---------|
| `nix/nodes/cid/default.nix` | Central config: tend, zoekt, codesearch, home.file, packages |
| `nix/flake.nix` | Flake inputs (all external repos) |
| `~/.config/tend/config.yaml` | Deployed tend config (do not edit directly) |
| `nix/nodes/cid/pleme-io-CLAUDE.md` | Source for pleme-io repo map |
| `nix/nodes/cid/workspace-CLAUDE.md` | Source for root workspace guide |
| `nix/nodes/cid/github-CLAUDE.md` | Source for GitHub-level guide |
