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

  ┌─────────────────── Shared Rust Libraries ───────────────────┐
  │  shikumi (config)  garasu (GPU primitives)  egaku (widgets) │
  │  irodori (colors)  irodzuki (GPU theming)  madori (app fw)  │
  │  mojiban (rich text)   oto (audio)  tsunagu (daemon IPC)    │
  │  todoku (HTTP)  hasami (clipboard)  awase (hotkeys)         │
  │  kaname (MCP scaffold)  soushi (Rhai)  tsuuchi (notify)     │
  │  denshin (WS gateway)  kenshou (auth)  eizou (media/WebRTC) │
  │  nami-core (browser core: DOM, CSS, layout)                 │
  └─────────────────────────────────────────────────────────────┘
            ↑ consumed by ↑
  ┌─────────────────── GPU Applications ────────────────────────┐
  │  mado (terminal)    hibikine (music)    kagibako (passwords)│
  │  mamorigami (VPN)   fumi (chat)         aranami (browser)   │
  │  namimado (desktop browser)  ayatsuri (wm)                  │
  │  tobirato (launcher) hikyaku (email)                        │
  │  tanken (files)     myaku (sysmon)      hikki (notes)       │
  │  shashin (images)   koyomiban (cal)     shirase (notify)    │
  └─────────────────────────────────────────────────────────────┘
            ↑ servers ↑
  ┌─────────────────── Server Applications ────────────────────┐
  │  hiroba (chat server — Stoat/Discord alternative)          │
  │  taimen (video conferencing — Visio/Zoom alternative)      │
  └────────────────────────────────────────────────────────────┘
```

**Hard rule:** User-specific data (names, IPs, SSH hosts, secrets, kubeconfigs) lives
ONLY in `nix`. Everything else is generic and public.

---

## Blackmatter Layer (shell + desktop tooling)

| Repo | Purpose | Language | Use as |
|------|---------|----------|--------|
| `blackmatter` | HM/nix-darwin module aggregator. Profiles (e.g. `frost`) select components | Nix | `inputs.blackmatter.homeManagerModules.default` |
| `blackmatter-shell` | Standalone zsh: 7 plugins, 35 Rust tools, starship. `nix run` for instant shell | Nix+Zsh | `packages.<sys>.blzsh` or HM module |
| `blackmatter-nvim` | Neovim: 56 plugins via lazy.nvim+Nix. Use nixpkgs treesitter parsers only | Nix+Lua | `packages.<sys>.blnvim` |
| `blackmatter-desktop` | Compositors (Hyprland/Sway/i3/Niri/GNOME/Cosmic), terminals, browsers. **Never containerized** | Nix | HM module |
| `blackmatter-claude` | Claude Code MCP servers, skills, hooks. Generic skills here | Nix+JSON | HM module |
| `blackmatter-pleme` | pleme-io org conventions, Claude skills for substrate builders | Nix+MD | HM module |
| `blackmatter-kubernetes` | K8s tooling: kubectl, k9s, k3d, helm, flux CLI | Nix | HM module |
| `blackmatter-akeyless` | Akeyless org integration: Nix builds, version matrix, workspace config | Nix | HM module |
| `blackmatter-atlassian` | Declarative acli + Rovo Dev provisioning, multi-site Atlassian config | Nix | HM module |
| `blackmatter-security` | 200+ pentesting tools by category | Nix | HM module |
| `blackmatter-profiles` | OCI shell images: `debug` (blzsh), `k8s` (debug+kubectl/helm/flux/k9s) | Nix | `ghcr.io/pleme-io/blackmatter-{debug,k8s}` |

**Key constraints:**
- Shell: Do NOT alias `find→fd` or `grep→rg` in `.bashrc` — guard with `[[ $- == *i* ]]`
- Nvim: Never pin nvim-treesitter to GitHub HEAD (parser/query version mismatch)
- Profiles: Add new profiles as `profiles/<name>/default.nix` using `lib/base-image.nix`

---

## Infrastructure & Platform

### `nix`
Private NixOS/nix-darwin config. Contains user identity, SSH hosts, SOPS secrets.
Consumes all blackmatter-* repos. Rebuild: `nix run .#darwin-rebuild`.
Secrets: `nix/secrets.yaml` (SOPS/age). Age key: `~/.config/sops/age/keys.txt`.

### `k8s`
GitOps manifests for K3s cluster (FluxCD). Kustomize bases + overlays for `plo` (prod)
and `zek` (staging). All Secrets SOPS-encrypted.
**Key constraint:** Use `encrypted_regex: "^(data|stringData)$"` (NOT `unencrypted_suffix`)
in `.sops.yaml` — kustomize label transformers run before decryption.

### `substrate`
Reusable Nix build patterns: `buildRustService`, `buildWebApp`, `buildDockerImage`.
Use: `inputs.substrate.lib.buildRustService { ... }`. Keep generic.

### `forge`
CI/CD build platform. Nix pipeline → Attic cache → GHCR → deployments.

---

## Products

### `nexus`
Primary product monorepo: `lilitu` + platform services (`hanabi`, `kenshi`, `shinka`, `zoekt-mcp`).
Structure: `pkgs/products/lilitu/`, `pkgs/platform/{hanabi,kenshi,shinka,zoekt-mcp}/`.
Build: `nix run .#release`. See `nexus/CLAUDE.md`.

### `lilitu`
Dating classifieds platform. TypeScript + React + MUI v7. `nix build` / `nix run .#release`.

### `hanabi`
BFF server. GraphQL federation gateway + WebSocket relay. Rust (Axum). Ports: 8080/8081.

### `kenshi`
GitOps ephemeral testing operator for K8s. Rust + Nix. ~76s test cycle.

### `shinka`
DB migration operator for K8s. Runs sqlx migrations via `Migration` CRD + FluxCD hooks. Rust.

---

## Shared Rust Libraries

All libraries: edition 2024, Rust 1.89.0+, MIT, clippy pedantic, release profile
(codegen-units=1, lto=true). Config via shikumi (`~/.config/{app}/{app}.yaml`).

### Dependency Graph

```
Application → madori (app framework) → garasu (GPU) → wgpu + winit + glyphon
            → egaku (widgets)        → irodori (colors)
            → shikumi (config)       → irodzuki (GPU theming) → egaku + bytemuck
            → nami-core (browser)    → html5ever + lightningcss + taffy
            → mojiban (rich text)    → pulldown-cmark
            → oto (audio)           → rodio + symphonia
            → kaname (MCP)          → rmcp 0.15
            → hasami (clipboard)    → arboard
            → soushi (scripting)    → rhai
            → tsunagu (daemon IPC)  → awase (hotkeys) → tsuuchi (notifications)
            → todoku (HTTP)         → denshin (WebSocket) → kenshou (auth)
            → eizou (media/WebRTC)
```

### Library Scope Guide

| Library | Scope | Does NOT do |
|---------|-------|-------------|
| garasu | GPU primitives (context, text, shaders, window) | Event loops, render loops, input |
| egaku | Widget state machines (focus, selection, scroll) | Rendering — consumers use garasu |
| madori | App framework (event loop, render loop, input dispatch) | GPU context internals |
| irodori | Color system (Nord palette, sRGB/linear, semantic) | GPU-specific uniforms (→ irodzuki) |
| irodzuki | Base16 → GPU uniforms, ANSI palette, shader vars | Color scheme definitions |
| shikumi | Config loading (discovery, hot-reload, ArcSwap) | App logic |
| mojiban | Text → styled spans (markdown, syntax highlighting) | Rendering |
| oto | Audio state machines (player, queue, codec) | I/O — consumers bring rodio |
| kaname | MCP server scaffold (tool registry, response helpers) | Tool implementations |
| todoku | HTTP client (auth, retry, JSON) | WebSocket, gRPC |
| hasami | Clipboard (copy, paste, history, timed clear) | Secure zeroize |
| tsunagu | Daemon lifecycle (PID, sockets, health) | RPC schema |
| tsuuchi | Notification dispatch (backends, history) | Platform APIs |
| soushi | Rhai scripting (engine, builtins, loading) | App-specific script APIs |
| awase | Hotkey abstraction (key types, parser, manager trait) | Platform registration |
| denshin | WebSocket gateway (connections, broadcasting, rooms) | HTTP |
| kenshou | Auth (providers, tokens, sessions, OAuth2/OIDC) | Business logic |
| eizou | Media/WebRTC (SFU, tracks, routing) | Signaling |
| nami-core | Browser core (DOM, CSS, layout, content blocking) | Rendering |

### Library Quick Reference

Each library is a git dep: `name = { git = "https://github.com/pleme-io/{name}" }`
or crates.io: `name = "0.1"`. Key APIs per library:

- **shikumi**: `ConfigDiscovery::new("app")`, `ConfigStore::<T>::load(&path, "PREFIX_")`, YAML files
- **garasu**: `GpuContext`, `TextRenderer`, `ShaderPipeline`, `AppWindow`. Shader plugin: bindings 0-2 (texture, sampler, uniforms)
- **madori**: `App::builder(renderer).title("...").size(w,h).on_event(handler).run()`, `RenderCallback` trait, `RenderContext`
- **egaku**: `TextInput`, `ScrollView`, `ListView`, `TabBar`, `SplitPane`, `Modal`, `FocusManager`, `Theme`
- **irodori**: `NordPalette`, `SemanticColors`, `Color` (sRGB↔linear, hex, lerp)
- **irodzuki**: `ColorScheme` (base16, `to_egaku_theme()`), `GpuColors::from_scheme()`, `ThemeUniforms` (bytemuck Pod), `THEME_UNIFORMS_WGSL`
- **mojiban**: `MarkdownParser::parse()` → `Vec<RichLine>`, `SyntaxHighlighter::highlight()`, `StyledSpan`
- **oto**: `Player`, `Queue`, `Decoder`, `AudioDevice`, `VoiceStream`
- **kaname**: `prelude`, `json_ok`/`json_err`/`json_result`, `server_info()`, `run()`, `KanameError`. Pinned rmcp 0.15
- **todoku**: `HttpClient::builder().base_url().auth().retry().build()`, `get/post/put/delete<T>()`, `Auth` trait, `RetryPolicy`
- **hasami**: `ClipboardManager`, `ClipboardHistory`, `TimedClear`
- **tsunagu**: `DaemonProcess`, `SocketPath`, `HealthCheck`
- **tsuuchi**: `NotificationManager`, `NotificationBackend` trait, `Notification`
- **soushi**: `ScriptEngine::new()`, `register_builtins()`, `load_scripts(dir)`, `eval(script)`
- **awase**: `HotkeyParser::parse("Cmd+Shift+Space")`, `Hotkey`, `HotkeyManager` trait
- **denshin**: `WsGateway`, `ConnectionManager`, `EventBroadcaster`
- **kenshou**: `AuthProvider`, `TokenValidator`, `SessionManager`
- **eizou**: `MediaRouter`, `SfuSession`, `TrackPublisher`, `TrackSubscriber`
- **nami-core**: DOM (html5ever), CSS (lightningcss), layout (taffy), content blocking. Features: `network`, `config`

---

## GPU Applications

All GPU apps share: garasu (GPU), egaku (widgets), shikumi (config), tsunagu (daemon),
Nix flake with `overlays.default` + `homeManagerModules.default` + `packages` + `devShells`.

### `mado` — Terminal Emulator
GPU-rendered terminal (Ghostty philosophy). Pure Rust, wgpu Metal/Vulkan.
- **Deps:** garasu, madori, vte (VT100), shikumi, hasami
- **Architecture:** Two threads (main + PTY/tokio), target four-thread model
- **GPU:** RectPipeline (instanced rects) + glyphon per-row text with per-cell color spans
- **VT:** CUU/CUD/CUP/ED/EL/SGR/DECSTBM/alt screen/mouse/bracketed paste/sync output. Missing: OSC 52/8/133, Kitty protocols
- **See:** `mado/CLAUDE.md` for full roadmap

### `hibikine` — Music Player *(repo: hibiki, binary: hibiki)*
GPU music player + BitTorrent. Deps: garasu, oto, librqbit, shikumi.
FLAC/ALAC/WAV lossless, gapless, magnet links, DHT, waveform visualizer.

### `kagibako` — 1Password Client *(repo: kagi, binary: kagi)*
GPU 1Password client. Deps: garasu, reqwest, arboard, zeroize, shikumi.
Fuzzy search, secure clipboard auto-clear, biometric unlock via `op` CLI.

### `mamorigami` — NordVPN Client *(repo: kekkai, binary: kekkai)*
GPU NordVPN client. Deps: garasu, reqwest, shikumi.
Server map, smart selection, NordLynx/WireGuard, kill switch.

### `fumi` — Multi-Protocol Chat Client
GPU chat for Discord + Matrix + Slack. Deps: garasu, egaku, mojiban, oto, serenity, matrix-sdk, shikumi.
Multi-protocol, E2E encryption, voice chat, rich text, daemon mode.

### `aranami` — TUI Browser *(repo: nami, binary: nami)*
GPU TUI browser. Deps: nami-core, garasu, egaku, mojiban, shikumi.
HTML5+CSS rendering (no JS initially), vim-like nav, tracker blocking.
Shares browser core with namimado via nami-core.

### `namimado` — Desktop Browser
Desktop browser with Servo engine + garasu GPU chrome.
Deps: nami-core, garasu, egaku, irodzuki, shikumi, Servo (via Nix).
Features: `browser-core` (nami-core), `gpu-chrome` (garasu/egaku/irodzuki/shikumi).

### Existing apps (see their own CLAUDE.md)

| App | Description | Binary | Key deps |
|-----|-------------|--------|----------|
| `tobirato` | App launcher | `tobira` | wgpu, winit, shikumi, sakuin, kiroku |
| `hikyaku` | Email client | `hikyaku` | ratatui-image, chromiumoxide, shikumi, async-imap |
| `ayatsuri` | Window manager | `ayatsuri` | bevy, rhai, rmcp |

### Planned GPU apps

| App | Description | Key deps |
|-----|-------------|----------|
| `tanken` | File manager | garasu, egaku, shikumi |
| `myaku` | System monitor | garasu, egaku, shikumi, sysinfo |
| `hikki` | Note editor | garasu, egaku, mojiban, shikumi |
| `shashin` | Image viewer | garasu, image, shikumi |
| `koyomiban` (bin: `koyomi`) | Calendar | garasu, egaku, todoku, shikumi |
| `shirase` | Notification center | garasu, egaku, tsuuchi, shikumi |

---

## Server Applications

### `hiroba` — Chat Server *(Stoat/Discord alternative)*
Rust. Deps: denshin, kenshou, tokio, axum. Channels, roles, voice rooms, federation-ready.
Client: fumi connects to hiroba as one of its chat protocols.

### `taimen` — Video Conferencing *(Visio/Zoom alternative)*
Rust. Deps: eizou, kenshou, denshin, tokio, axum. WebRTC SFU, screen sharing, recording.

---

## Tools & Libraries

| Repo | Purpose | Language |
|------|---------|----------|
| `codesearch` | Semantic code search (BM25 + embeddings + tree-sitter) | Rust |
| `zoekt-mcp` | MCP wrapper for Zoekt trigram search | Rust |
| `curupira` | MCP for browser/React debugging via Chrome DevTools | TypeScript |
| `pleme-linker` | Nix-native npm resolver for hermetic builds | Rust+Nix |
| `libraries` | Shared Rust crates + TypeScript packages (`@pleme/*`) | Rust+TS |
| `tend` | Workspace repo manager + version watch daemon (`tend sync`, `tend watch`, `tend daemon`) | Rust |
| `akeyless-matrix` | Version matrix manager for Akeyless Nix packages (`certify`, `generate`, `status`) | Rust |
| `akeyless-api` | Auto-generated Rust SDK for Akeyless API (604 endpoints, 1334 types, from OpenAPI spec) | Rust |
| `akeyless-nix` | Akeyless secret management for Nix — drop-in sops-nix replacement (`install`, `check`) | Rust+Nix |
| `dev-tools` | Developer workflow scripts | — |
| `kindling` | Nix flake management CLI | Rust |
| `kontena` | Container runtime daemon (podman/colima) for macOS | Rust |
| `blx` | Shell extensions for blackmatter-shell | Rust |
| `pangea-akeyless` | Akeyless provider for Pangea DSL (117 resources, 22 data sources) | Ruby |
| `atlassian-nix` | Nix packages for Atlassian CLI tools (acli, Rovo Dev) | Nix |

---

## Nix Integration Patterns

### Application flake.nix (tobirato pattern)

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    substrate = { url = "github:pleme-io/substrate"; inputs.nixpkgs.follows = "nixpkgs"; };
  };
  outputs = { self, nixpkgs, substrate, ... }: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; };
    package = pkgs.rustPlatform.buildRustPackage { ... };
  in {
    packages.${system}.default = package;
    overlays.default = final: prev: { appname = self.packages.${final.system}.default; };
    homeManagerModules.default = import ./module {
      hmHelpers = import "${substrate}/lib/hm-service-helpers.nix" { lib = nixpkgs.lib; };
    };
    devShells.${system}.default = pkgs.mkShellNoCC { ... };
  };
}
```

### Library flake.nix (substrate rust-library.nix)

```nix
rustLibrary = import "${substrate}/lib/rust-library.nix" {
  inherit system nixpkgs; nixLib = substrate; inherit crate2nix;
};
lib = rustLibrary { name = "libname"; src = ./.; };
```

### Cargo.toml conventions

- Prefer crates.io deps (all pleme libraries are published)
- Git deps fallback: `{ git = "https://github.com/pleme-io/crate" }`
- Edition 2024, rust-version 1.89.0, MIT license
- Release: `codegen-units = 1`, `lto = true`, `opt-level = "z"`, `strip = true`
- `[lints.clippy] pedantic = "warn"`
- All repos are PUBLIC on GitHub

### Flake Input Conventions

Always follow nixpkgs through to avoid closure duplication:

```nix
blackmatter-foo = {
  url = "github:pleme-io/blackmatter-foo";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

When `blackmatter` (aggregator) is an input, override ALL sub-inputs:
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
