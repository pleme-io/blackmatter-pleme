# blackmatter-pleme

Pleme-io organization conventions, Claude Code skills, and workspace infrastructure as a
Nix home-manager module. Provides 17 builder skills for scaffolding projects in Rust,
TypeScript, Go, Zig, Ruby, and Helm, plus org workflow skills for flake propagation,
workspace management, and skill authoring. Also manages the CLAUDE.md documentation
hierarchy, tend workspace configuration, and Zoekt/Codesearch indexing for 100+ repos.

## Architecture

```
flake.nix
  └── homeManagerModules.default → module/default.nix
                                      ├── Skills       → ~/.claude/skills/{name}/SKILL.md
                                      ├── CLAUDE.md    → ~/code/**/CLAUDE.md hierarchy
                                      ├── Workspace    → ~/.config/tend/config.yaml
                                      │                   ~/code/github/pleme-io/.envrc
                                      └── Indexing     → services.zoekt.daemon.repos
                                                         services.codesearch.daemon.github.sources

skills/                  ← auto-discovered at build time
  ├── rust-service/      ← substrate builder skills (Rust, TS, Go, Zig, Ruby)
  ├── rust-library/
  ├── ...
  └── workspace-management/  ← org workflow skills

docs/                    ← deployed as CLAUDE.md hierarchy
  ├── workspace-CLAUDE.md    → ~/code/CLAUDE.md
  ├── github-CLAUDE.md       → ~/code/github/CLAUDE.md
  └── pleme-io-CLAUDE.md     → ~/code/github/pleme-io/CLAUDE.md
```

The module has four independent concerns, each with its own `enable` toggle:
skills deployment, CLAUDE.md hierarchy, tend workspace config, and search indexing.

## Features

### Substrate Builder Skills (10 skills)

Scaffolding skills for creating new projects that use the pleme-io substrate build system:

| Skill              | Description                                                   |
|--------------------|---------------------------------------------------------------|
| `rust-service`     | Dockerized Rust microservice with GraphQL, migrations, K8s    |
| `rust-library`     | Reusable Rust crate with CI and substrate integration         |
| `rust-binary`      | Standalone Rust CLI binary                                    |
| `rust-tool`        | Rust developer tool with substrate's buildRustTool            |
| `rust-wasm`        | Rust WebAssembly library/app                                  |
| `typescript-webapp`| React/TypeScript web application with pleme-linker            |
| `typescript-library` | Reusable TypeScript package                                |
| `typescript-tool`  | TypeScript CLI tool                                           |
| `go-tool`          | Go CLI tool using substrate's mkGoTool                        |
| `go-monorepo`      | Multi-binary Go monorepo using mkGoMonorepoSource             |
| `zig-tool`         | Zig CLI tool using substrate's mkZigOverlay                   |
| `ruby-gem`         | Ruby gem library                                              |
| `ruby-service`     | Ruby web service                                              |

### Org Workflow Skills (4 skills)

| Skill                  | Description                                               |
|------------------------|-----------------------------------------------------------|
| `pleme-flake-update`   | Propagate flake.lock updates across the repo dependency chain via tend |
| `workspace-management` | Add repos, configure indexing, expand tend config, manage CLAUDE.md |
| `claude-skills`        | Author and maintain Claude Code skills in blackmatter-claude/pleme |
| `helm-k8s-charts`      | Create Helm 4 charts for Kubernetes services with FluxCD integration |

### CLAUDE.md Hierarchy

Deploys three documentation files that provide progressive context to Claude Code
as it navigates the workspace:

| Deployed Path                          | Source                      | Content                          |
|----------------------------------------|-----------------------------|----------------------------------|
| `~/code/CLAUDE.md`                     | `docs/workspace-CLAUDE.md`  | Workspace directory conventions  |
| `~/code/github/CLAUDE.md`             | `docs/github-CLAUDE.md`     | GitHub service conventions       |
| `~/code/github/pleme-io/CLAUDE.md`    | `docs/pleme-io-CLAUDE.md`   | Full org repo map and architecture |

### Workspace Configuration

Generates `~/.config/tend/config.yaml` with the pleme-io workspace definition
including flake dependency chains for `tend flake-update`. Also deploys a
`~/code/github/pleme-io/.envrc` with `use_tend` for auto-sync on directory entry.

### Search Indexing

Provides default repo lists for two code search systems:

- **Zoekt** (trigram search): 100+ pleme-io repos pre-configured for `services.zoekt.daemon.repos`
- **Codesearch** (semantic search): pleme-io org auto-discovery for `services.codesearch.daemon.github.sources`

Both lists are extensible via `indexing.extraZoektRepos` and `indexing.codesearchSources`.

## Installation

Add as a flake input and enable the home-manager module:

```nix
# flake.nix
{
  inputs.blackmatter-pleme = {
    url = "github:pleme-io/blackmatter-pleme";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then import the module:

```nix
# home-manager configuration
{ inputs, ... }: {
  imports = [ inputs.blackmatter-pleme.homeManagerModules.default ];
}
```

## Usage

### Minimal Configuration

```nix
{
  blackmatter.components.pleme = {
    enable = true;
  };
}
```

This enables all four concerns with their defaults: skills, CLAUDE.md hierarchy,
tend workspace config, and Zoekt/Codesearch indexing.

### Full Configuration

```nix
{
  blackmatter.components.pleme = {
    enable = true;

    # Skills — auto-discovered from skills/ directory
    skills = {
      enable = true;
      extraSkills = {
        my-custom-skill = ./my-custom-skill/SKILL.md;
      };
    };

    # CLAUDE.md hierarchy deployment
    claudeMd.enable = true;

    # Workspace — tend config + .envrc
    workspace = {
      enable = true;
      extraTendWorkspaces = ''
        - name: drzln
          provider: github
          base_dir: ~/code/github/drzln
          clone_method: ssh
          discover: true
          org: drzln
      '';
    };

    # Indexing — zoekt + codesearch repo lists
    indexing = {
      enable = true;
      extraZoektRepos = [
        "~/code/github/drzln/dotfiles"
        "~/code/github/drzln/homelab"
      ];
    };
  };
}
```

### Adding Extra Tend Workspaces

The `workspace.extraTendWorkspaces` option appends additional workspace entries
to the generated `~/.config/tend/config.yaml`:

```nix
{
  blackmatter.components.pleme.workspace.extraTendWorkspaces = ''
    - name: binti-family
      provider: github
      base_dir: ~/code/github/binti-family
      clone_method: ssh
      discover: true
      org: binti-family
  '';
}
```

## Configuration Reference

### Option Tree

```
blackmatter.components.pleme
├── enable                          # Master toggle (default: false)
├── skills
│   ├── enable                      # Deploy skills (default: true)
│   └── extraSkills                 # Additional SKILL.md files (attrset)
├── claudeMd
│   └── enable                      # Deploy CLAUDE.md hierarchy (default: true)
├── workspace
│   ├── enable                      # Deploy tend config + .envrc (default: true)
│   └── extraTendWorkspaces         # Extra YAML workspace entries (string)
└── indexing
    ├── enable                      # Provide zoekt/codesearch repo lists (default: true)
    ├── zoektRepos                  # Override default zoekt repo list
    ├── extraZoektRepos             # Append to default zoekt repo list
    └── codesearchSources           # Override codesearch GitHub source configs
```

### Zoekt Indexing

The default `zoektRepos` list covers all pleme-io org repos organized by category:
infrastructure (nix, k8s, substrate, forge), blackmatter ecosystem (14 repos),
products (nexus, lilitu, hanabi, kenshi, shinka), tools and libraries (15 repos),
platform libraries (30+ pleme-* crates), and infrastructure-as-code repos (pangea-*).

### Codesearch Sources

By default, codesearch uses org-level auto-discovery:

```nix
[{
  owner = "pleme-io";
  kind = "org";
  cloneBase = "~/code/github/pleme-io";
  skipArchived = true;
  skipForks = false;
}]
```

## Development

```bash
# Check the flake
nix flake check

# Build the module (evaluated as part of home-manager)
nix build .#homeManagerModules.default
```

### Adding a New Skill

1. Create `skills/{name}/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill
   description: When to invoke this skill
   allowed-tools: Read, Write, Edit, Glob, Grep, Bash
   metadata:
     version: "1.0.0"
     domain_keywords:
       - "keyword1"
       - "keyword2"
   ---
   ```
2. Add the skill content below the frontmatter
3. The module auto-discovers it at build time and deploys to `~/.claude/skills/{name}/SKILL.md`

### Updating the Zoekt Repo List

Edit `defaultZoektRepos` in `module/default.nix` to add or remove repos from the
default indexing set. For user-specific additions, use `indexing.extraZoektRepos`
in your nix configuration instead.

## Project Structure

```
blackmatter-pleme/
├── flake.nix                          # Flake — exports homeManagerModules.default
├── module/
│   └── default.nix                    # Home-manager module (skills, CLAUDE.md, workspace, indexing)
├── skills/
│   ├── rust-service/SKILL.md          # Dockerized Rust microservice builder
│   ├── rust-library/SKILL.md          # Rust crate builder
│   ├── rust-binary/SKILL.md           # Rust CLI binary builder
│   ├── rust-tool/SKILL.md             # Rust developer tool builder
│   ├── rust-wasm/SKILL.md             # Rust WebAssembly builder
│   ├── typescript-webapp/SKILL.md     # React/TypeScript web app builder
│   ├── typescript-library/SKILL.md    # TypeScript package builder
│   ├── typescript-tool/SKILL.md       # TypeScript CLI tool builder
│   ├── go-tool/SKILL.md              # Go CLI tool builder
│   ├── go-monorepo/SKILL.md          # Go monorepo builder
│   ├── zig-tool/SKILL.md             # Zig CLI tool builder
│   ├── ruby-gem/SKILL.md             # Ruby gem builder
│   ├── ruby-service/SKILL.md         # Ruby web service builder
│   ├── helm-k8s-charts/SKILL.md      # Helm 4 chart creator
│   ├── pleme-flake-update/SKILL.md   # Flake update chain propagation
│   ├── workspace-management/SKILL.md # Workspace and indexing management
│   └── claude-skills/SKILL.md        # Skill authoring guide
└── docs/
    ├── workspace-CLAUDE.md            # ~/code/CLAUDE.md source
    ├── github-CLAUDE.md               # ~/code/github/CLAUDE.md source
    └── pleme-io-CLAUDE.md             # ~/code/github/pleme-io/CLAUDE.md source
```

## Related Projects

| Project | Description |
|---------|-------------|
| [blackmatter-claude](https://github.com/pleme-io/blackmatter-claude) | Generic Claude Code integration (LSP, MCP servers, skills framework) |
| [blackmatter](https://github.com/pleme-io/blackmatter) | Home-manager module aggregator — consumes this repo |
| [substrate](https://github.com/pleme-io/substrate) | Nix build patterns (buildRustService, mkGoTool, etc.) |
| [tend](https://github.com/pleme-io/tend) | Workspace repository manager CLI |
| [zoekt-mcp](https://github.com/pleme-io/zoekt-mcp) | Zoekt trigram search MCP server |
| [codesearch](https://github.com/pleme-io/codesearch) | Semantic code search MCP server |
| [nix](https://github.com/pleme-io/nix) | User-specific NixOS/nix-darwin config (private) |

## License

MIT
