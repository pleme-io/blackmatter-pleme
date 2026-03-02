# GitHub Workspace

All GitHub-hosted repositories, organized by org or user account.

## Current Orgs

| Directory | Description |
|-----------|-------------|
| `pleme-io/` | Primary org — infrastructure, products, platform libraries, tools |
| `drzln/` | Personal repositories |
| `binti-family/` | Family project repositories |

Each org directory may have its own `CLAUDE.md` with org-specific guidance.
See `pleme-io/CLAUDE.md` for the most detailed example.

## Adding a New Org

1. Create the directory: `mkdir -p ~/code/github/new-org`
2. Add a tend workspace via `blackmatter.components.pleme.workspace.extraTendWorkspaces`
   in the nix repo, or add to `blackmatter-pleme/module/default.nix` if it's a pleme-io org:
   ```yaml
   - name: new-org
     provider: github
     base_dir: ~/code/github/new-org
     clone_method: ssh
     discover: true
     org: new-org
   ```
3. Rebuild: `nix run .#rebuild` (from the nix repo)
4. Run `tend sync --workspace new-org`
5. Optionally add repos to Zoekt/Codesearch indexing

## Conventions

- **Clone method:** SSH (`git@github.com:org/repo.git`)
- **Authentication:** `GITHUB_TOKEN` env var for API access (set via sops secret)
- **Discovery:** `tend` auto-discovers org repos via the GitHub API when `discover: true`
- **Indexing:** Zoekt (trigram) and Codesearch (semantic) indexes are configured per-org in `blackmatter-pleme/module/default.nix`

## Direnv

Org directories with `.envrc` files containing `use_tend` will auto-sync repos
on directory entry. Individual repo `.envrc` files (e.g., `use flake`) are
independent — direnv is directory-scoped and does not inherit from parents.
