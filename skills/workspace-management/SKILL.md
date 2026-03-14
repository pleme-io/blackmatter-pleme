---
name: workspace-management
description: Manage the pleme-io workspace — add repos, configure Zoekt/Codesearch indexing, expand tend config, add new orgs, and maintain the CLAUDE.md hierarchy. Use when onboarding new repos, setting up indexing for new projects, or expanding the workspace structure.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "2.0.0"
  last_verified: "2026-03-01"
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

Configuration is split between two repos:
- **blackmatter-pleme** — org-specific config (zoekt repos, codesearch sources, tend workspace, CLAUDE.md files)
- **nix** — private config (daemon enable flags, token paths, personal workspaces)

## Adding a New Repo to the Workspace

When a new repo is created in the pleme-io org:

### 1. Tend auto-discovers it

If `discover: true` is set (it is for pleme-io), `tend sync` picks it up automatically.
No config change needed for discovery.

### 2. Add to Zoekt indexing

Edit `blackmatter-pleme/module/default.nix`, find the `defaultZoektRepos` list,
and add the new repo path:

```nix
defaultZoektRepos = let base = "~/code/github/pleme-io"; in [
  # ... existing repos ...
  "${base}/new-repo"    # ← add here
];
```

Zoekt indexes trigram patterns for instant exact-match search.

### 3. Codesearch auto-discovers

Codesearch is configured with `kind = "org"` for pleme-io, so it auto-discovers
repos via the GitHub API. No manual addition needed unless you want to index
repos from outside the org.

### 4. Push and rebuild

```bash
cd ~/code/github/pleme-io/blackmatter-pleme
git add module/default.nix && git commit -m "feat: add new-repo to zoekt indexing" && git push
tend flake-update --changed blackmatter-pleme
```

## Adding a New Org

### 1. Create directory

```bash
mkdir -p ~/code/github/new-org
```

### 2. Add tend workspace

For pleme-io-related orgs, add to `blackmatter-pleme/module/default.nix` in the
`plemeWorkspaceYaml` block.

For personal/private orgs, add via `blackmatter.components.pleme.workspace.extraTendWorkspaces`
in the nix repo:

```nix
blackmatter.components.pleme.workspace.extraTendWorkspaces = ''
  - name: new-org
    provider: github
    base_dir: ~/code/github/new-org
    clone_method: ssh
    discover: true
    org: new-org
    exclude: []
    extra_repos: []
'';
```

### 3. Add Zoekt repos (if needed)

For pleme-io repos: add to `defaultZoektRepos` in `blackmatter-pleme/module/default.nix`.

For personal repos: use `blackmatter.components.pleme.indexing.extraZoektRepos` in nix:
```nix
blackmatter.components.pleme.indexing.extraZoektRepos = [
  "~/code/github/new-org/some-repo"
];
```

### 4. Add Codesearch source (if needed)

Add to `defaultCodesearchSources` in `blackmatter-pleme/module/default.nix`:

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

Create the CLAUDE.md file in `blackmatter-pleme/docs/` and deploy via the module,
or in the nix repo for private content.

### 6. Optionally add .envrc

Add to `blackmatter-pleme/module/default.nix` config section:

```nix
home.file."code/github/new-org/.envrc".text = "use_tend\n";
```

After rebuild, run `direnv allow ~/code/github/new-org/.envrc` once.

### 7. Push and rebuild

```bash
# If changes in blackmatter-pleme:
cd ~/code/github/pleme-io/blackmatter-pleme && git add -A && git commit -m "feat: add new-org" && git push
tend flake-update --changed blackmatter-pleme

# If changes only in nix:
cd ~/code/github/pleme-io/nix && nix run .#rebuild
```

## CLAUDE.md Hierarchy

Each level provides progressively more specific guidance, managed by dedicated modules:

| File | Deployed From | Content |
|------|--------------|---------|
| `~/code/CLAUDE.md` | `blackmatter-code/docs/code-CLAUDE.md` | Directory convention, how to add services/orgs |
| `~/code/github/CLAUDE.md` | `blackmatter-github/docs/github-CLAUDE.md` | GitHub-specific conventions, org table (generated from orgEntries) |
| `~/code/github/pleme-io/CLAUDE.md` | `blackmatter-pleme/docs/pleme-io-CLAUDE.md` | Full repo map, architecture, contribution guide |
| `~/code/github/akeyless-community/CLAUDE.md` | `blackmatter-akeyless/docs/akeyless-community-CLAUDE.md` | Akeyless community repo map |
| `~/code/github/akeylesslabs/CLAUDE.md` | `blackmatter-akeyless/docs/akeylesslabs-CLAUDE.md` | Akeyless official repo map |

To update any CLAUDE.md, edit the source file in the appropriate blackmatter module and rebuild.
Do NOT edit the deployed symlinks directly.

### Composable Registration

Org modules register themselves with their parent layer:
- `blackmatter-github` registers with `blackmatter-code` via `serviceEntries`
- `blackmatter-pleme`, `blackmatter-akeyless` register with `blackmatter-github` via `orgEntries`
- Personal orgs (drzln, binti-family) register via the `nix` repo

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

Edit `nix/nodes/cid/workspace.nix`:

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
| `blackmatter-pleme/module/default.nix` | Org config: zoekt repos, codesearch sources, tend workspace, CLAUDE.md |
| `nix/nodes/cid/workspace.nix` | Private: packages, stateVersion, extra workspaces |
| `nix/nodes/cid/mcp-services.nix` | Private: daemon enable flags, token paths |
| `nix/flake.nix` | Flake inputs (all external repos) |
| `~/.config/tend/config.yaml` | Deployed tend config (do not edit directly) |
