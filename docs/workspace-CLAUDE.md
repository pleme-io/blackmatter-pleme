# Workspace Root

All source code lives under `~/code/` following a strict directory convention:

```
~/code/${git-service}/${org-or-user}/${repo}
```

Example:
```
~/code/github/pleme-io/nexus
~/code/github/drzln/dotfiles
~/code/gitlab/my-org/some-repo
```

## Current Layout

```
~/code/
  github/
    pleme-io/    ← primary org (infrastructure, products, tools)
    drzln/       ← personal repos
    binti-family/ ← family project repos
```

Each level can have its own `CLAUDE.md` with progressively more specific guidance:
- `~/code/CLAUDE.md` — this file (workspace-wide conventions)
- `~/code/github/CLAUDE.md` — GitHub-specific conventions
- `~/code/github/pleme-io/CLAUDE.md` — org-specific repo map and rules

## Adding a New Git Service

To add a new service (e.g., GitLab, Codeberg):

1. Create the directory: `mkdir -p ~/code/gitlab/my-org`
2. Add a workspace entry in `~/.config/tend/config.yaml`
3. Add the repos to Zoekt indexing in `blackmatter-pleme/module/default.nix`
4. Optionally create a `CLAUDE.md` at the service and org levels
5. Rebuild: `nix run .#rebuild` (from the nix repo)

## Adding a New Org Under an Existing Service

1. Create the directory: `mkdir -p ~/code/github/new-org`
2. Add a tend workspace entry for the new org
3. Run `tend sync --workspace new-org`
4. Add repos to Zoekt/Codesearch indexing as needed

## Repo Sync

`tend` manages workspace repo discovery and cloning. Run `tend status` to see
which repos are clean, dirty, missing, or unknown. Run `tend sync` to clone
all missing repos across all configured workspaces.

Config: `~/.config/tend/config.yaml`

## Nix Integration

Org-specific workspace configuration (tend config, CLAUDE.md files, Zoekt repos,
Codesearch sources) is declared in `blackmatter-pleme/module/default.nix` and deployed
via `home-manager` on rebuild. Private overrides (extra workspaces, daemon tokens)
live in the `nix` repo. Edit the source repos, not the deployed files.
