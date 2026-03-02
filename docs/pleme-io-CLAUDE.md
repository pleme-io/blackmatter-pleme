# pleme-io Repository Map

All repositories under `~/code/github/pleme-io/`. Read this before touching any repo.

---

## Architecture Overview

```
                    nix  ←── user/org-specific config (private, never public)
                   /  \
        blackmatter    k8s  ←── GitOps manifests
        /    |    \
  -shell  -nvim  -desktop  -claude  -pleme  -kubernetes  -security
     \       |
      blackmatter-profiles  ←── OCI containers (no desktop, no user data)

  substrate  ←── Nix build patterns consumed by product repos
  pleme-linker ←── npm resolver for Nix builds
  nexus  ←── product monorepo (lilitu, platform services)
```

**Hard rule:** User-specific data (names, IPs, SSH hosts, secrets, kubeconfigs) lives
ONLY in `nix`. Everything else is generic and public.

---

## Blackmatter Layer (shell + desktop tooling)

### `blackmatter`
Main home-manager/nix-darwin module aggregator. Pulls in all blackmatter-* component
repos and exposes them as a single `homeManagerModules.default` + `darwinModules.default`.
Profiles (e.g. `frost`) are defined here — they select which components to enable and
set sane defaults without any user-identifying data.

- **Language:** Nix
- **Use:** `inputs.blackmatter.homeManagerModules.default` in `nix/flake.nix`
- **Contribute:** Add a new profile under `module/profiles/`, or a new component under
  `modules/home-manager/blackmatter/components/`. Each component follows the pattern:
  `enable` option + `mkIf cfg.enable { ... }` config block.
- **Inputs:** nixpkgs, sops-nix, fenix, claude-code, all blackmatter-* repos

### `blackmatter-shell`
Standalone zsh distribution. 7 plugins, 35 Rust-based tools (bat, eza, fd, rg, delta,
etc.), starship prompt. Exports `packages.<system>.blzsh` — a self-contained shell binary
that sets `ZDOTDIR` to a nix store path. `nix run github:pleme-io/blackmatter-shell`
drops into a fully configured shell on any machine with Nix.

- **Language:** Nix + Zsh
- **Use:** `inputs.blackmatter-shell.packages.${system}.blzsh` for the binary;
  `inputs.blackmatter-shell.homeManagerModules.default` for the HM module.
- **Contribute:** Plugins live in `module/plugins/<author>/<name>/`. Shell groups
  (aliases, functions, completion) are in `module/groups/`. `package.nix` is the
  standalone derivation — all tool paths are embedded at build time.
- **Key constraint:** Do NOT alias `find→fd` or `grep→rg` in `.bashrc` — incompatible
  flag syntax breaks non-interactive shell invocations (BASH_ENV sources .bashrc in all
  bash invocations). Guard `.bashrc` aliases with `[[ $- == *i* ]]`.

### `blackmatter-nvim`
Neovim distribution. 56 curated plugins managed by lazy.nvim via Nix. Exports
`packages.<system>.blnvim`. Uses nixpkgs treesitter parsers (never pin nvim-treesitter
to GitHub HEAD — parser/query version mismatch causes `except*` errors).

- **Language:** Nix + Lua
- **Use:** `inputs.blackmatter-nvim.packages.${system}.blnvim`
- **Contribute:** Add plugins in `plugins/` following the plugin-helper.nix pattern.
  Use `pluginOverride = pkgs: pkgs.vimPlugins.foo` when a nixpkgs package exists
  (avoids GitHub fetch + ensures treesitter version alignment).

### `blackmatter-desktop`
Desktop environment modules: compositors (Hyprland, Sway, i3, Niri, GNOME, Cosmic),
terminals (Kitty, Alacritty), browsers (Chrome, Firefox), video tools.
**Never containerized** — GUI has no meaning in a container.

- **Language:** Nix
- **Use:** `inputs.blackmatter-desktop.homeManagerModules.default`
- **Contribute:** Each compositor/app gets its own directory under `module/`. Keep all
  configuration generic (no personal keybindings, usernames, or paths that identify a user).

### `blackmatter-claude`
Claude Code integration. MCP server configuration, custom skills, hooks, and LSP setup
for the Zoekt/Codesearch MCP tools. Used in home-manager to configure Claude Code's
working environment.

- **Language:** Nix + JSON
- **Use:** `inputs.blackmatter-claude.homeManagerModules.default`
- **Contribute:** Add new MCP server configs or skills. Prefer generic skills
  (not pleme-io-specific) in this repo; pleme-io-specific skills live in
  `blackmatter-pleme`.

### `blackmatter-pleme`
Pleme-io org conventions and Claude Code skills for standardized Rust development.
Contains skills for substrate builders (rust-library, rust-binary, rust-tool, rust-service)
and org workflows (flake updates, helm charts, skill authoring, workspace management).

- **Language:** Nix + Markdown
- **Use:** `inputs.blackmatter-pleme.homeManagerModules.default`
- **Contribute:** Add new pleme-io-specific skills under `skills/{name}/SKILL.md`.
  Generic Claude Code skills belong in `blackmatter-claude`, not here.

### `blackmatter-kubernetes`
Kubernetes tooling modules: kubectl, k9s, k3d, helm, flux CLI, and related utilities.
Home-manager module that installs and configures these tools.

- **Language:** Nix
- **Use:** `inputs.blackmatter-kubernetes.homeManagerModules.default`
- **Contribute:** Add new K8s tools under `module/`. Keep generic — no cluster-specific
  config (kubeconfigs, contexts, namespaces live in `nix`).

### `blackmatter-security`
Penetration testing and security research toolkit. 200+ tools organized by category
(recon, exploitation, forensics, etc.). Home-manager module.

- **Language:** Nix
- **Use:** `inputs.blackmatter-security.homeManagerModules.default`
- **Contribute:** Add tools under the appropriate category module. Only include tools
  available in nixpkgs or with a clean Nix derivation.

### `blackmatter-profiles`
Shell profiles packaged as OCI container images. Generic, public, no user data.
Imports `blackmatter-shell` and composes profiles for specific use cases.
Only shell profiles — no desktop, no GUI.

- **Language:** Nix
- **Profiles:** `debug` (full blzsh tool suite), `k8s` (debug + kubectl/helm/flux/k9s)
- **Images:** `ghcr.io/pleme-io/blackmatter-debug`, `ghcr.io/pleme-io/blackmatter-k8s`
- **Use in K8s:**
  ```bash
  kubectl run debug --image=ghcr.io/pleme-io/blackmatter-debug:latest --rm -it --restart=Never
  kubectl debug -it <pod> --image=ghcr.io/pleme-io/blackmatter-k8s:latest
  ```
- **Contribute:** Add a new profile as `profiles/<name>/default.nix` using the
  `lib/base-image.nix` helper, then add it to the CI matrix in `.github/workflows/containers.yml`.
  Images push on every merge to main: `:latest` + `:<sha>`.

---

## Infrastructure & Platform

### `nix`
Personal NixOS/nix-darwin configuration for `cid` (the dev machine). Private — contains
user identity, SSH hosts, secrets (SOPS-encrypted), and personal preferences. Consumes
all blackmatter-* repos as flake inputs and wires everything together.

- **Language:** Nix (flake-parts)
- **Rebuild:** `nix run .#darwin-rebuild` (from within the repo)
- **Contribute:** This repo is user/org-specific — generic improvements belong in the
  appropriate blackmatter-* repo, not here.
- **Secrets:** All credentials in `nix/secrets.yaml` (SOPS/age encrypted).
  Age key at `~/.config/sops/age/keys.txt`.

### `k8s`
GitOps manifests for the pleme-io K3s cluster, reconciled by FluxCD. Contains Kustomize
bases + overlays for both `plo` (production) and `zek` (staging) clusters. All Secret
YAMLs are SOPS-encrypted with `encrypted_regex: "^(data|stringData)$"`.

- **Language:** YAML (Kubernetes manifests + Kustomize + FluxCD)
- **Contribute:** Never apply manifests directly — all changes go through git.
  FluxCD reconciles from this repo. To add a new service: create
  `shared/infrastructure/<name>/base/` with kustomization.yaml, add to appropriate
  cluster overlay.
- **Key constraint:** Use `encrypted_regex: "^(data|stringData)$"` (NOT
  `unencrypted_suffix`) in `.sops.yaml` — kustomize label transformers run before
  decryption and break the default suffix pattern.

### `substrate`
Reusable Nix build patterns: `buildRustService`, `buildWebApp`, `buildDockerImage`, etc.
Used by product repos (lilitu, hanabi, shinka, etc.) as the standard way to build
Rust services and web frontends reproducibly.

- **Language:** Nix
- **Use:** `inputs.substrate.lib.buildRustService { ... }`
- **Contribute:** Add new build helpers under `lib/`. Keep patterns generic — no
  product-specific logic here.

### `forge`
CI/CD build platform. Manages the Nix build pipeline: building images, pushing to
registries (Attic cache, GHCR), and triggering deployments. Uses Attic for binary
caching (`attic push nexus`).

- **Language:** Nix + shell
- **Contribute:** Add new build jobs or pipeline steps.

---

## Products

### `nexus`
The primary product monorepo. Contains `lilitu` (dating classifieds platform) and all
platform services (`hanabi`, `kenshi`, `shinka`, `zoekt-mcp`).

- **Structure:** `pkgs/products/lilitu/`, `pkgs/platform/{hanabi,kenshi,shinka,zoekt-mcp}/`
- **Build:** `nix run .#release` (product-level) or `nix run .#release:backend` (service)
- **Test:** Via Kenshi ephemeral environments on the K8s cluster
- **See also:** `nexus/CLAUDE.md` for detailed product architecture

### `lilitu`
Dating classifieds platform (extracted from nexus). Frontend React app.

- **Language:** TypeScript + React + MUI v7
- **Build:** `nix build` / `nix run .#release`

### `hanabi`
BFF (Backend-for-Frontend) server. GraphQL federation gateway + WebSocket relay.
Handles auth, routing, and real-time events for all Nexus products.

- **Language:** Rust (Axum)
- **Port:** 8080 (HTTP), 8081 (WebSocket)

### `kenshi`
GitOps-native ephemeral testing operator for Kubernetes. Provisions test environments
on-demand, runs test suites, tears down when done. Reads `TestEnvironment` CRDs.

- **Language:** Rust + Nix
- **Test cycle:** ~76s for custom tests (backend-health, graphql-schema, migration-verify)

### `shinka`
Database migration operator for Kubernetes. Runs sqlx migrations as a Kubernetes Job,
managed via `Migration` CRD. Integrates with FluxCD lifecycle hooks.

- **Language:** Rust

---

## Tools & Libraries

### `codesearch`
Fast local semantic code search. BM25 + vector embeddings + tree-sitter AST parsing.
Natural language queries, fully local (no external API). Used as an MCP server by
Claude Code via `zoekt-mcp`.

- **Language:** Rust
- **Use:** `mcp__codesearch__semantic_search`, `mcp__codesearch__find_references`

### `zoekt-mcp`
MCP server wrapping Zoekt trigram-indexed code search. Instant exact-match search
across all indexed repos. Always prefer this over `grep` for code search.

- **Language:** Rust
- **Use:** `mcp__zoekt__search` with `file:`, `lang:`, `sym:`, `repo:` filters

### `curupira`
MCP server for browser/React debugging. Traces component state, Apollo cache, network
requests, and console messages in Chrome DevTools. Used for frontend debugging.

- **Language:** TypeScript
- **Use:** `mcp__curupira__*` tools for React/browser debugging

### `pleme-linker`
Nix-native JavaScript package manager. Resolves npm dependencies hermetically for Nix
builds without network access in the sandbox. Used by all web frontend builds.

- **Language:** Rust + Nix
- **Use:** `inputs.pleme-linker` in substrate-based web app builds

### `libraries`
Shared platform libraries: Rust crates (error types, auth primitives, etc.) and
TypeScript packages (`@pleme/*`). Consumed by product services.

- **Language:** Rust + TypeScript

### `tend`
Workspace repository manager. Discovers and clones GitHub org repos, tracks
status (clean/dirty/missing), integrates with direnv via `use_tend`.

- **Language:** Rust
- **Use:** `tend sync`, `tend status`, `tend discover <org>`

### `dev-tools`
Developer workflow tools specific to the pleme-io ecosystem. Scripts and utilities
for common development tasks.

---

## Flake Input Conventions

When adding a new blackmatter-* repo as an input anywhere, always follow nixpkgs
(and shared deps) through to avoid duplicate copies in the closure:

```nix
blackmatter-foo = {
  url = "github:pleme-io/blackmatter-foo";
  inputs.nixpkgs.follows = "nixpkgs";
  # follow any other shared inputs declared by blackmatter-foo
};
```

When `blackmatter` (the aggregator) is an input, override ALL its sub-inputs:
```nix
blackmatter = {
  url = "github:pleme-io/blackmatter";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.follows = "sops-nix";
  inputs.fenix.follows = "fenix";
  inputs.claude-code.follows = "claude-code";
  inputs.blackmatter-nvim.follows = "blackmatter-nvim";
  inputs.blackmatter-shell.follows = "blackmatter-shell";
  inputs.blackmatter-claude.follows = "blackmatter-claude";
  inputs.blackmatter-desktop.follows = "blackmatter-desktop";
  inputs.blackmatter-security.follows = "blackmatter-security";
  inputs.blackmatter-kubernetes.follows = "blackmatter-kubernetes";
};
```
