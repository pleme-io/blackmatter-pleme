{ skillHelpers }:
{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.blackmatter.components.pleme;

  # Skills via substrate helper
  skills = skillHelpers.mkSkills {
    skillsDir = ../skills;
    extraSkills = cfg.skills.extraSkills;
  };

  # Default zoekt repo list — all pleme-io org repos worth indexing
  defaultZoektRepos = let base = "~/code/github/pleme-io"; in [
    # Infrastructure & config
    "${base}/nix"
    "${base}/k8s"
    "${base}/substrate"
    "${base}/forge"
    # Blackmatter ecosystem
    "${base}/blackmatter"
    "${base}/blackmatter-shell"
    "${base}/blackmatter-nvim"
    "${base}/blackmatter-claude"
    "${base}/blackmatter-desktop"
    "${base}/blackmatter-ghostty"
    "${base}/blackmatter-security"
    "${base}/blackmatter-kubernetes"
    "${base}/blackmatter-go"
    "${base}/blackmatter-zig"
    "${base}/blackmatter-macos"
    "${base}/blackmatter-opencode"
    "${base}/blackmatter-tend"
    "${base}/blackmatter-services"
    "${base}/blackmatter-pleme"
    "${base}/blackmatter-profiles"
    # Products
    "${base}/nexus"
    "${base}/lilitu"
    "${base}/hanabi"
    "${base}/kenshi"
    "${base}/shinka"
    # Tools & libraries
    "${base}/compass.nvim"
    "${base}/zoekt-mcp"
    "${base}/codesearch"
    "${base}/curupira"
    "${base}/umbra"
    "${base}/pleme-linker"
    "${base}/arachne-plugins"
    "${base}/arachne"
    "${base}/tend"
    "${base}/libraries"
    "${base}/dev-tools"
    "${base}/fleet"
    "${base}/helmworks"
    # Platform libraries
    "${base}/pleme-types"
    "${base}/pleme-config"
    "${base}/pleme-database"
    "${base}/pleme-migrations"
    "${base}/pleme-health"
    "${base}/pleme-observability"
    "${base}/pleme-auth-sdk"
    "${base}/pleme-graphql-helpers"
    "${base}/pleme-codegen"
    "${base}/pleme-hooks"
    "${base}/pleme-error"
    "${base}/pleme-error-boundary"
    "${base}/pleme-testing"
    "${base}/pleme-i18n"
    "${base}/pleme-ui-components"
    "${base}/pleme-form-system"
    "${base}/pleme-image-upload"
    "${base}/pleme-analytics"
    "${base}/pleme-notifications"
    "${base}/pleme-providers"
    "${base}/pleme-redis"
    "${base}/pleme-rbac"
    "${base}/pleme-support"
    "${base}/pleme-state-machines"
    "${base}/pleme-zustand-patterns"
    "${base}/pleme-web-observability"
    "${base}/pleme-apollo-config"
    "${base}/pleme-service-foundation"
    "${base}/pleme-builder-core"
    "${base}/pleme-config-manager"
    "${base}/pleme-graphql-request-client"
    "${base}/pleme-auth-tokens"
    "${base}/pleme-auth-sessions"
    "${base}/pleme-auth-validators"
    "${base}/pleme-auth-mfa"
    "${base}/pleme-middleware-rate-limit"
    "${base}/pleme-brazilian-utils"
    "${base}/pleme-brazilian-validators"
    # Infrastructure
    "${base}/pleme-infra"
    "${base}/pangea"
    "${base}/pangea-core"
    "${base}/pangea-kubernetes"
    "${base}/pangea-hcloud"
    "${base}/pangea-aws"
    "${base}/pangea-gcp"
    "${base}/pangea-azure"
    "${base}/pangea-cloudflare"
    # Other
    "${base}/boreal"
    "${base}/abstract-synthesizer"
    "${base}/terraform-synthesizer"
  ];

  # Default codesearch sources — pleme-io org auto-discovery
  defaultCodesearchSources = [{
    owner = "pleme-io";
    kind = "org";
    cloneBase = "~/code/github/pleme-io";
    skipArchived = true;
    skipForks = false;
  }];

  # Pleme-io tend workspace YAML
  plemeWorkspaceYaml = ''
    workspaces:
      - name: pleme-io
        provider: github
        base_dir: ~/code/github/pleme-io
        clone_method: ssh
        discover: true
        org: pleme-io
        exclude:
          - ".github"
        extra_repos: []
        flake_deps:
          blackmatter-shell:
            - blackmatter-nvim
          blackmatter-kubernetes:
            - blackmatter-go
          blackmatter-profiles:
            - blackmatter-nvim
            - blackmatter-shell
          blackmatter:
            - blackmatter-nvim
            - blackmatter-shell
            - blackmatter-claude
            - blackmatter-desktop
            - blackmatter-ghostty
            - blackmatter-security
            - blackmatter-kubernetes
            - blackmatter-opencode
            - blackmatter-tend
            - blackmatter-pleme
            - blackmatter-services
          nix:
            - blackmatter
            - blackmatter-nvim
            - compass.nvim
            - blackmatter-shell
            - blackmatter-claude
            - blackmatter-desktop
            - blackmatter-ghostty
            - blackmatter-security
            - blackmatter-go
            - blackmatter-zig
            - blackmatter-kubernetes
            - blackmatter-opencode
            - blackmatter-tend
            - blackmatter-pleme
            - blackmatter-services
            - blackmatter-profiles
  '';
in {
  options.blackmatter.components.pleme = {
    enable = mkEnableOption "Pleme-io org conventions, workspace config, and skills";

    # ── Skills (via substrate hm-skill-helpers) ────────────────────────
    skills = skillHelpers.mkSkillOptions;

    # ── CLAUDE.md hierarchy ───────────────────────────────────────────
    claudeMd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy CLAUDE.md files for the workspace/org hierarchy";
      };
    };

    # ── Workspace (tend config, .envrc) ───────────────────────────────
    workspace = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy tend workspace config and .envrc for pleme-io org";
      };
      extraTendWorkspaces = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Extra YAML lines appended after the pleme-io workspace in tend config.
          Should be indented workspace entries (same level as the pleme-io entry).
        '';
      };
    };

    # ── Indexing (zoekt repos, codesearch sources) ────────────────────
    indexing = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Provide pleme-io repo lists for zoekt and codesearch indexing. Only enable when zoekt-mcp and codesearch HM modules are loaded.";
      };
      zoektRepos = mkOption {
        type = types.listOf types.str;
        default = defaultZoektRepos;
        description = "Zoekt repo paths to index. Defaults to all pleme-io org repos.";
      };
      extraZoektRepos = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional zoekt repo paths to append to the default list.";
      };
      codesearchSources = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = defaultCodesearchSources;
        description = "Codesearch GitHub source configs. Defaults to pleme-io org.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # ── Skills (via substrate hm-skill-helpers) ──────────────────────
    (mkIf (cfg.skills.enable && skills.files != {}) {
      home.file = skills.homeFiles;
    })

    # ── CLAUDE.md hierarchy ─────────────────────────────────────────
    (mkIf cfg.claudeMd.enable {
      home.file."code/github/pleme-io/CLAUDE.md".source = ../docs/pleme-io-CLAUDE.md;

      # Register pleme-io with blackmatter-github org table
      blackmatter.components.github.claudeMd.orgEntries."pleme-io" = {
        description = "Primary org -- infrastructure, products, platform libraries, tools";
        cloneMethod = "ssh";
      };
    })

    # ── Workspace ───────────────────────────────────────────────────
    (mkIf cfg.workspace.enable {
      home.file.".config/tend/config.yaml".text =
        plemeWorkspaceYaml + (lib.concatMapStringsSep "\n" (line:
          if line == "" then "" else "  " + line
        ) (lib.splitString "\n" cfg.workspace.extraTendWorkspaces));
      home.file."code/github/pleme-io/.envrc".text = "use_tend\n";
    })

    # ── Indexing ────────────────────────────────────────────────────
    (mkIf cfg.indexing.enable {
      services.zoekt.daemon.repos = cfg.indexing.zoektRepos ++ cfg.indexing.extraZoektRepos;
      services.zoekt.daemon.github.sources = [{
        owner = "pleme-io";
        kind = "org";
        cloneBase = "~/code/github/pleme-io";
        skipArchived = true;
        skipForks = false;
      }];
      services.codesearch.daemon.github.sources = cfg.indexing.codesearchSources;
    })
  ]);
}
