# blackmatter-pleme

Pleme-io org conventions, workspace management, indexing config, and Claude Code skills.

## Overview

Home-manager module that deploys pleme-io-specific configuration: Claude Code skills for standardized Rust/Nix development, CLAUDE.md hierarchy files, tend workspace config, and repo lists for Zoekt/Codesearch indexing. This is the org-specific counterpart to blackmatter-claude (which is generic).

## Flake Outputs

- `homeManagerModules.default` -- home-manager module at `blackmatter.components.pleme`

## Usage

```nix
{
  inputs.blackmatter-pleme.url = "github:pleme-io/blackmatter-pleme";
}
```

```nix
blackmatter.components.pleme = {
  enable = true;
  workspace.extraTendWorkspaces = ''
    - name: my-org
      provider: github
      base_dir: ~/code/github/my-org
      clone_method: ssh
      discover: true
      org: my-org
  '';
  indexing.extraZoektRepos = [ "~/code/github/my-org/my-repo" ];
};
```

## What It Manages

- **Skills:** auto-discovered from `skills/` directory, deployed to `~/.claude/skills/`
- **CLAUDE.md:** workspace, GitHub, and pleme-io org hierarchy files
- **Workspace:** tend config (`~/.config/tend/config.yaml`) + `.envrc` for pleme-io
- **Indexing:** Zoekt repo paths + Codesearch GitHub source configs

## Structure

- `module/` -- home-manager module
- `skills/` -- pleme-io Claude Code skills (SKILL.md files)
- `docs/` -- CLAUDE.md hierarchy source files
