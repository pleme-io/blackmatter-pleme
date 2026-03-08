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
  │  todoku (HTTP)  hikidashi (clipboard)  hasami (clip+hist)   │
  │  kotoha (MCP)  kaname (MCP scaffold)  awase (hotkeys)       │
  │  soushi (Rhai)  tsuuchi (notify)  denshin (WS gateway)      │
  │  kenshou (auth)  eizou (media/WebRTC)                       │
  └─────────────────────────────────────────────────────────────┘
            ↑ consumed by ↑
  ┌─────────────────── GPU Applications ────────────────────────┐
  │  mado (terminal)    hibikine (music)    kagibako (passwords)│
  │  mamorigami (VPN)   fumi (chat)         aranami (browser)   │
  │  tobirato (launcher) hikyaku (email)    ayatsuri (wm)       │
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

## Shared Rust Libraries

These libraries form the reusable foundation for all pleme-io GPU applications.
Every library uses: edition 2024, Rust 1.89.0+, MIT license, clippy pedantic,
release profile (codegen-units=1, lto=true). Config via shikumi
(`~/.config/{app}/{app}.yaml`, env override `{APP}_CONFIG`, prefix `{APP}_`).

### Dependency Graph

```
Application (tobirato, tanken, myaku, hikki, shashin, koyomiban, shirase,
             mado, hibikine, kagibako, mamorigami, fumi, aranami)
       │
       ├── shikumi (config: discovery, figment providers, ArcSwap hot-reload)
       ├── garasu (GPU primitives: wgpu context, text, shaders)
       │     └── wgpu + winit + glyphon
       ├── egaku (widgets: text input, lists, tabs, splits, modals, Theme)
       ├── irodori (colors: Nord palette, sRGB/linear, semantic colors)
       ├── hasami (clipboard: copy/paste, history, timed clear)
       │     └── arboard
       ├── tsuuchi (notifications: dispatch, history, backends)
       ├── kaname (MCP: server scaffold, tool registry, response helpers)
       │     └── rmcp 0.15
       ├── soushi (scripting: Rhai engine setup, builtins, script loading)
       │     └── rhai
       ├── awase (hotkeys: key types, parser, platform-agnostic manager)
       ├── mojiban (rich text: markdown → styled spans, syntax highlighting)
       │     └── pulldown-cmark
       ├── oto (audio: player state, queue, codec detection, voice state)
       ├── tsunagu (daemon IPC: PID lifecycle, Unix sockets, health checks)
       │
       │  Planned:
       ├── madori (app framework: event loop, render loop, input dispatch)
       ├── irodzuki (GPU theming: base16 → wgpu uniforms, ANSI colors)
       └── todoku (HTTP: authenticated requests, retry, JSON)
```

### Library Distinction Guide

**Do NOT confuse these — each has a precise scope:**

| Library | Scope | Does NOT do |
|---------|-------|-------------|
| garasu | GPU primitives (context, text renderer, shaders, window creation) | Event loops, render loops, input handling |
| egaku | Widget state machines (focus, selection, scroll position) | Rendering — consumers paint widgets via garasu |
| irodori | Color system (Nord palette, sRGB/linear conversion, semantic colors) | GPU-specific color uniforms — see irodzuki (planned) |
| hasami | Clipboard (copy, paste, history, timed clear) | Secure zeroize — see hikidashi (planned) |
| tsuuchi | Notification dispatch (backends, history, rate limiting) | Platform notification APIs — consumers implement backends |
| kaname | MCP server scaffold (tool registry, response helpers, rmcp boilerplate) | Tool implementations — consumers define tools |
| soushi | Rhai scripting (engine setup, builtins, script loading) | App-specific script APIs — consumers register functions |
| awase | Hotkey abstraction (key types, parser, platform-agnostic manager trait) | Platform hotkey registration — consumers implement per-OS |
| mojiban | Text → styled spans (markdown, syntax highlighting) | Rendering — consumers feed spans to garasu text |
| oto | Audio state machines (player, queue, codec detection) | Actual I/O — consumers bring rodio/symphonia |
| tsunagu | Daemon lifecycle (PID, socket paths, health) | RPC schema — consumers bring tonic/proto |
| shikumi | Config loading (discovery, hot-reload, ArcSwap) | App logic — just provides `T` to consumers |
| madori *(planned)* | App framework (event loop, render loop, input dispatch) | GPU context internals |
| todoku *(planned)* | HTTP client (auth, retry, JSON) | WebSocket, gRPC |
| irodzuki *(planned)* | Base16 → GPU uniforms, ANSI palette, shader color vars | Color scheme definitions |

### `shikumi` — Configuration Library
Config discovery, hot-reload, and ArcSwap store for Nix-managed desktop apps.
Abstracts figment and imposes pleme-io configuration standards.

- **Language:** Rust
- **API:** `ConfigDiscovery` (XDG + env override), `ProviderChain` (defaults → env → file),
  `ConfigStore<T>` (lock-free ArcSwap with file watcher), `ConfigWatcher` (symlink-aware)
- **Dep:** `shikumi = { git = "https://github.com/pleme-io/shikumi" }`
- **Convention:** Every app uses `ConfigDiscovery::new("appname").env_override("APPNAME_CONFIG")`
  then `ConfigStore::<AppConfig>::load(&path, "APPNAME_")`. Config files are YAML.
- **Consumers:** tobirato, hikyaku, mado, hibikine, kagibako, mamorigami, fumi, aranami

### `garasu` — GPU Rendering Primitives
Low-level wgpu + winit + glyphon rendering stack. Metal on macOS, Vulkan on Linux.
**Library, not framework** — consumers own the event loop and render pass.

- **Language:** Rust
- **API:** `GpuContext` (device/queue/surface), `TextRenderer` (glyphon text),
  `ShaderPipeline` (WGSL post-processing), `AppWindow` (winit window creation)
- **Dep:** `garasu = { git = "https://github.com/pleme-io/garasu" }`
- **Shader plugin API:** input_texture (binding 0), input_sampler (binding 1),
  uniforms (binding 2: time, resolution). Custom shaders: `~/.config/{app}/shaders/*.wgsl`
- **Does NOT provide:** event loops, render loops, input dispatch — see madori
- **Consumers:** madori, egaku, mojiban, all GPU applications

### `madori` — GPU App Framework
Application shell that uses garasu. Provides the event loop → GPU init → render loop →
input dispatch scaffold that every GPU app needs. ~200 lines of identical boilerplate
eliminated per app.

- **Language:** Rust
- **API:** `App::builder(renderer).title("...").size(w,h).on_event(handler).run()`,
  `RenderCallback` trait (render/resize/init), `RenderContext` (gpu, text, surface_view,
  elapsed, dt), `AppEvent`/`KeyEvent`/`MouseEvent` (platform-independent input),
  `KeyCode::from_winit()` (winit → abstract key mapping)
- **Dep:** `madori = { git = "https://github.com/pleme-io/madori" }`
- **Built on:** garasu (GPU context, text), egaku (widget state), winit (event loop)
- **Consumers:** mado, hibikine, kagibako, mamorigami, fumi, aranami

### `egaku` — GPU Widget Toolkit
UI primitives built on garasu. Pure state machines — consumers render via garasu.

- **Language:** Rust
- **API:** `TextInput`, `ScrollView`, `ListView`, `TabBar`, `SplitPane`, `Modal`,
  `FocusManager`, `KeyMap`, `Theme` (Nord defaults, serde-compatible)
- **Dep:** `egaku = { git = "https://github.com/pleme-io/egaku" }`
- **Design:** Widgets are state, not rendering. Consumers call garasu to paint them.
- **Consumers:** all GPU applications with interactive UI

### `mojiban` — Rich Text Rendering *(renamed from fude)*
Converts markdown, code, and structured text into styled glyph runs for garasu.

- **Language:** Rust
- **API:** `MarkdownParser::parse(source)` → `Vec<RichLine>`,
  `SyntaxHighlighter::highlight(source, lang)` → `Vec<RichLine>`,
  `StyledSpan` (text + color + weight + italic + monospace)
- **Dep:** `mojiban = { git = "https://github.com/pleme-io/mojiban" }`
- **Backends:** pulldown-cmark (markdown), tree-sitter (syntax highlighting)
- **Consumers:** fumi (chat markdown), aranami (HTML content), mado (terminal), hibikine (lyrics)
- **crates.io:** `mojiban` (fude was taken)

### `oto` — Audio Framework
Shared audio primitives for music playback and voice communication.

- **Language:** Rust
- **API:** `Player` (play/pause/stop/volume), `Queue` (playlist, repeat, gapless),
  `Decoder` (codec detection), `AudioDevice`, `VoiceStream` (capture/playback, mute/deafen)
- **Dep:** `oto = { git = "https://github.com/pleme-io/oto" }`
- **Backends:** rodio (playback), symphonia (FLAC, ALAC, WAV, MP3, AAC, OGG, Opus)
- **Consumers:** hibikine (music playback), fumi (voice chat)

### `kaname` — MCP Server Framework *(renamed from hashira/kotoba)*
Shared boilerplate and helpers for building MCP servers with rmcp.

- **Language:** Rust
- **API:** `prelude` (re-exports all rmcp types), `json_ok`/`json_err`/`json_result`
  (consistent JSON formatting), `server_info()` (ServerInfo builder),
  `run()` (stdio entry point), `StatusInfo`/`UptimeTracker` (health tool),
  `KanameError` (common error type)
- **Dep:** `kaname = { git = "https://github.com/pleme-io/kaname" }`
- **Pinned rmcp:** 0.15 with `["server", "transport-io"]`
- **Consumers:** all MCP servers (zoekt-mcp, codesearch, ayatsuri, hikyaku, umbra,
  mathscape, mado, hibikine, kagibako, mamorigami, fumi, aranami)
- **crates.io:** `kaname` (hashira was taken)

### `todoku` — HTTP Client Framework
Shared authenticated HTTP client with retry and JSON deserialization. Wraps reqwest
so every app with API calls uses the same patterns.

- **Language:** Rust
- **API:** `HttpClient::builder().base_url(...).auth(BearerToken::new(...)).retry(policy).build()`,
  `get<T>()`, `post<B,T>()`, `put<B,T>()`, `delete<T>()`, `get_raw()` (no JSON),
  `Auth` trait (BearerToken, BasicAuth, HeaderAuth), `RetryPolicy` (exponential backoff,
  configurable status codes)
- **Dep:** `todoku = { git = "https://github.com/pleme-io/todoku" }`
- **Does NOT provide:** WebSocket, gRPC, or non-HTTP protocols
- **Consumers:** kagibako (1Password API), mamorigami (NordVPN API), aranami (web fetching),
  fumi (Slack REST), hibikine (metadata APIs)

### `hasami` — Clipboard Abstraction *(renamed from hikidashi)*
Thread-safe clipboard with history and timed clearing.

- **Language:** Rust
- **API:** `ClipboardManager` (copy/paste/clear), `ClipboardHistory` (recent entries),
  `TimedClear` (auto-clear after configurable duration)
- **Dep:** `hasami = { git = "https://github.com/pleme-io/hasami" }`
- **Built on:** arboard (cross-platform clipboard), tokio (timed operations)
- **Consumers:** kagibako (password copy), mado (terminal paste), fumi (message copy)
- **crates.io:** `hasami`

### `irodzuki` — GPU Theme System
Bridges base16 color schemes to GPU render pipelines. Our own "Stylix for GPU apps" —
standard Stylix themes NixOS/GTK/terminal apps but cannot reach into wgpu shader
uniforms, ANSI color tables, or custom GPU pipelines. irodzuki fills that gap.

- **Language:** Rust
- **API:** `ColorScheme` (base16 palette with serde, hex parsing, ANSI color generation,
  `to_egaku_theme()`), `GpuColors::from_scheme()` (wgpu-ready clear color, palette arrays),
  `ThemeUniforms` (bytemuck Pod for uniform buffer: background, foreground, accent, error,
  is_dark), `THEME_UNIFORMS_WGSL` (WGSL struct snippet for shaders),
  `Color` (RGBA with hex roundtrip, lerp, luminance, sRGB↔linear conversion)
- **Dep:** `irodzuki = { git = "https://github.com/pleme-io/irodzuki" }`
- **Built on:** egaku (Theme with base16 slots), bytemuck (zero-copy uniform upload)
- **Stylix integration:** Nix home-manager module maps `config.lib.stylix.colors` →
  egaku Theme base16 fields → irodzuki converts to GPU-native formats at runtime
- **Does NOT define color schemes** — it transforms egaku::Theme into GPU-consumable
  formats. Color scheme definitions come from Stylix/egaku.
- **Consumers:** mado (terminal ANSI colors + shader uniforms), hibikine (visualizer colors),
  kagibako, mamorigami, fumi, aranami (UI accent/background in GPU pipeline)

### `irodori` — Color & Theme System *(renamed from iro)*
Nord-inspired color palette with sRGB/linear conversion and semantic color mapping.

- **Language:** Rust
- **API:** `NordPalette` (all Nord colors), `SemanticColors` (bg, fg, accent, error, etc.),
  `Color` (RGBA with sRGB↔linear, hex roundtrip, lerp, luminance)
- **Dep:** `irodori = { git = "https://github.com/pleme-io/irodori" }`
- **Consumers:** garasu (GPU colors), egaku (widget theme), mojiban (markdown styling)
- **crates.io:** `irodori` (iro was taken)

### `tsuuchi` — Notification Framework
Platform-agnostic notification dispatch with trait-based backends.

- **Language:** Rust
- **API:** `NotificationManager` (dispatch, history), `NotificationBackend` trait,
  `Notification` (title, body, urgency, timeout)
- **Dep:** `tsuuchi = { git = "https://github.com/pleme-io/tsuuchi" }`
- **Consumers:** shirase (notification center), all apps with user alerts
- **crates.io:** `tsuuchi`

### `soushi` — Rhai Scripting Engine
Shared Rhai engine setup with builtins and script loading for user-extensible apps.

- **Language:** Rust
- **API:** `ScriptEngine::new()`, `register_builtins()`, `load_scripts(dir)`,
  `eval(script)`, builtin math/string/array functions
- **Dep:** `soushi = { git = "https://github.com/pleme-io/soushi" }`
- **Consumers:** ayatsuri (window manager scripting), future apps with user scripting
- **crates.io:** `soushi`

### `awase` — Global Hotkey Abstraction *(renamed from kukan)*
Key types, parser, and platform-agnostic hotkey manager trait.

- **Language:** Rust
- **API:** `HotkeyParser::parse("Cmd+Shift+Space")`, `Hotkey` (modifier + key),
  `HotkeyManager` trait (register/unregister), `Modifier`/`KeyCode` enums
- **Dep:** `awase = { git = "https://github.com/pleme-io/awase" }`
- **Consumers:** tobirato (launcher hotkey), ayatsuri (window management shortcuts)
- **crates.io:** `awase` (kukan was taken)

### `tsunagu` — Daemon IPC Framework
Service/daemon lifecycle management for apps with background processes.

- **Language:** Rust
- **API:** `DaemonProcess` (PID file, stale detection, cleanup-on-drop),
  `SocketPath` (XDG-compliant Unix socket paths), `HealthCheck` (liveness/readiness)
- **Dep:** `tsunagu = { git = "https://github.com/pleme-io/tsunagu" }`
- **Design:** Manages daemon process lifecycle, not RPC schema. Consumers define their
  own `.proto` files and use tonic for gRPC.
- **Consumers:** all apps with daemon/background service mode

### `denshin` — WebSocket Gateway
Real-time WebSocket gateway framework for server applications.

- **Language:** Rust
- **API:** `WsGateway`, `ConnectionManager`, `EventBroadcaster`, room/channel multiplexing
- **Dep:** `denshin = { git = "https://github.com/pleme-io/denshin" }`
- **Consumers:** hiroba (chat server), taimen (signaling)
- **crates.io:** `denshin`

### `kenshou` — Authentication Framework
Authentication and authorization library for server applications.

- **Language:** Rust
- **API:** `AuthProvider`, `TokenValidator`, `SessionManager`, OAuth2/OIDC flows
- **Dep:** `kenshou = { git = "https://github.com/pleme-io/kenshou" }`
- **Consumers:** hiroba (user auth), taimen (meeting auth)
- **crates.io:** `kenshou`

### `eizou` — Media/WebRTC Framework
WebRTC media handling for video/audio streaming in server applications.

- **Language:** Rust
- **API:** `MediaRouter`, `SfuSession`, `TrackPublisher`, `TrackSubscriber`
- **Dep:** `eizou = { git = "https://github.com/pleme-io/eizou" }`
- **Consumers:** taimen (video conferencing), hiroba (voice channels)
- **crates.io:** `eizou`

---

## GPU Applications

All GPU applications follow the same patterns:
- GPU rendering via garasu (Metal/Vulkan)
- UI widgets via egaku
- Configuration via shikumi (`~/.config/{app}/{app}.yaml`)
- Daemon mode via tsunagu
- Nix integration: `flake.nix` with `overlays.default`, `homeManagerModules.default`,
  `packages`, `devShells` (following tobirato/substrate patterns)
- Nord color theme defaults

### `mado` — Terminal Emulator
GPU-rendered terminal emulator following Ghostty's philosophy, written in Rust.

- **Language:** Rust
- **crates.io:** `mado`
- **Key deps:** garasu (GPU), vte (VT100 parsing), nix (PTY), shikumi (config)
- **Modules:** `render` (GPU pipeline), `terminal` (VT state machine), `pty` (shell spawn),
  `platform` (macOS objc2 / Linux), `config` (shikumi)
- **Features:** GPU text rendering, WGSL shader plugins, VT100/xterm emulation,
  split panes, tabs, platform-native integration

### `hibikine` — Music Player + BitTorrent *(repo: hibiki)*
GPU-rendered music player with built-in BitTorrent client for hi-fi music.

- **Language:** Rust
- **crates.io:** `hibikine` (hibiki was taken)
- **Binary:** `hibiki` (via `[[bin]] name = "hibiki"`)
- **Key deps:** garasu (GPU), oto (audio), librqbit (BitTorrent), shikumi (config)
- **Modules:** `audio` (rodio+symphonia), `torrent` (librqbit), `library` (metadata scan),
  `render` (GPU UI), `config` (shikumi)
- **Features:** FLAC/ALAC/WAV lossless playback, gapless, magnet links, DHT,
  library management, waveform visualizer

### `kagibako` — 1Password Client *(repo: kagi)*
GPU-rendered 1Password client. Uses 1Password service and API for all vault operations.

- **Language:** Rust
- **crates.io:** `kagibako` (kagi was taken)
- **Binary:** `kagi` (via `[[bin]] name = "kagi"`)
- **Key deps:** garasu (GPU), reqwest (1Password API), arboard (clipboard),
  zeroize (secure memory), shikumi (config)
- **Modules:** `api` (1Password Connect + `op` CLI), `vault` (data models),
  `clipboard` (auto-clear), `render` (GPU vault browser), `config` (shikumi)
- **Features:** fuzzy search, secure clipboard auto-clear, biometric unlock via `op` CLI

### `mamorigami` — NordVPN Client *(repo: kekkai)*
GPU-rendered NordVPN client. Uses NordVPN service for all VPN operations.

- **Language:** Rust
- **crates.io:** `mamorigami` (kekkai was taken)
- **Binary:** `kekkai` (via `[[bin]] name = "kekkai"`)
- **Key deps:** garasu (GPU), reqwest (NordVPN API), shikumi (config)
- **Modules:** `api` (NordVPN REST + CLI), `servers` (selection/filtering),
  `connection` (lifecycle), `render` (GPU server map), `config` (shikumi)
- **Features:** server map visualization, smart server selection, NordLynx/WireGuard,
  kill switch management

### `fumi` — Multi-Protocol Chat Client
GPU-rendered unified chat client for Discord, Matrix, and Slack.

- **Language:** Rust
- **crates.io:** `fumi`
- **Key deps:** garasu (GPU), egaku (widgets), mojiban (rich text), oto (voice),
  serenity (Discord), matrix-sdk (Matrix), shikumi (config)
- **Modules:** `protocol` (common trait), `discord` (serenity), `matrix` (matrix-sdk),
  `slack` (REST+WebSocket), `render` (GPU UI), `config` (multi-account)
- **Features:** multi-protocol, E2E encryption (Matrix), voice chat, rich text,
  reactions, embeds, daemon mode for persistent connections, desktop notifications

### `aranami` — TUI Browser *(repo: nami)*
GPU-rendered TUI browser. Full web rendering in a GPU-accelerated interface.

- **Language:** Rust
- **crates.io:** `aranami` (nami was taken)
- **Binary:** `nami` (via `[[bin]] name = "nami"`)
- **Key deps:** garasu (GPU), egaku (widgets), mojiban (rich text), html5ever (HTML),
  lightningcss (CSS), taffy (flexbox/grid layout), shikumi (config)
- **Modules:** `dom` (HTML parsing), `css` (cascade), `layout` (taffy), `fetch` (reqwest),
  `render` (GPU content), `config` (shikumi)
- **Features:** HTML5 parsing, CSS cascade, flexbox/grid layout, inline images,
  keyboard navigation (vim-like), bookmarks, HTTPS-only mode, tracker blocking
- **No JavaScript** initially — static HTML+CSS rendering, JS via boa_engine later

### `tobirato` — App Launcher *(repo: tobira)*
GPU-rendered fast app launcher for macOS and Linux. (Already exists.)

- **Language:** Rust
- **crates.io:** `tobirato` (tobira was taken)
- **Binary:** `tobira` (via `[[bin]] name = "tobira"`)
- **Key deps:** wgpu, winit, glyphon, shikumi, sakuin (tantivy), kiroku (SeaORM)
- **Architecture:** See `tobira/CLAUDE.md`

### `hikyaku` — Email Client
TUI email client with GPU-assisted rendering. (Already exists.)

- **Language:** Rust
- **crates.io:** `hikyaku`
- **Key deps:** ratatui-image, chromiumoxide, shikumi, async-imap, lettre
- **Architecture:** See `hikyaku/CLAUDE.md`

### `ayatsuri` — Window Manager
macOS window management via Bevy ECS. (Already exists.)

- **Language:** Rust
- **crates.io:** `ayatsuri`
- **Binary:** `ayatsuri`
- **Key deps:** bevy, rhai (scripting), rmcp (MCP server)
- **Architecture:** See `ayatsuri/CLAUDE.md`

### `tanken` — File Manager
GPU-rendered file manager with fast navigation and preview.

- **Language:** Rust
- **crates.io:** `tanken`
- **Key deps:** garasu (GPU), egaku (widgets), shikumi (config)
- **Features:** fast directory navigation, file preview, bulk operations, tabs

### `myaku` — System Monitor
GPU-rendered system monitor with real-time resource graphs.

- **Language:** Rust
- **crates.io:** `myaku`
- **Key deps:** garasu (GPU), egaku (widgets), shikumi (config), sysinfo
- **Features:** CPU, memory, disk, network graphs, process list, GPU metrics

### `hikki` — Note Editor
GPU-rendered markdown note editor with wiki links and knowledge graph.

- **Language:** Rust
- **crates.io:** `hikki`
- **Key deps:** garasu (GPU), egaku (widgets), sumifude (rich text), shikumi (config)
- **Features:** markdown editing, wiki links, backlinks, knowledge graph visualization

### `shashin` — Image Viewer
GPU-rendered image viewer with fast gallery and metadata display.

- **Language:** Rust
- **crates.io:** `shashin`
- **Key deps:** garasu (GPU), image (decoding), shikumi (config)
- **Features:** fast gallery, EXIF metadata, zoom/pan, basic editing, slideshow

### `koyomiban` — Calendar
GPU-rendered calendar with scheduling and sync.

- **Language:** Rust
- **crates.io:** `koyomiban` (koyomi was taken)
- **Binary:** `koyomi` (via `[[bin]] name = "koyomi"`)
- **Key deps:** garasu (GPU), egaku (widgets), todoku (HTTP), shikumi (config)
- **Features:** calendar views, reminders, CalDAV sync, recurring events

### `shirase` — Notification Center
GPU-rendered unified notification management.

- **Language:** Rust
- **crates.io:** `shirase`
- **Key deps:** garasu (GPU), egaku (widgets), tsuuchi (notifications), shikumi (config)
- **Features:** notification aggregation, filtering, history, do-not-disturb

---

## Server Applications

Server-side applications that complement the GPU client apps.

### `hiroba` — Chat Server *(Stoat/Discord alternative)*
Open-source chat server. Provides the server-side infrastructure for real-time
text/voice communication, similar to Discord/Stoat but built in pleme-io style.

- **Language:** Rust
- **crates.io:** `hiroba`
- **Key deps:** denshin (WebSocket gateway), kenshou (auth), tokio, axum, serde
- **Features:** channels, roles, permissions, voice rooms, federation-ready,
  WebSocket gateway for real-time messaging
- **Client:** fumi connects to hiroba as one of its chat protocols

### `taimen` — Video Conferencing *(Visio/Zoom alternative)*
Open-source video conferencing server. Provides WebRTC-based video/audio
conferencing, similar to La Suite Meet/Zoom but built in pleme-io style.

- **Language:** Rust
- **crates.io:** `taimen`
- **Key deps:** eizou (media/WebRTC), kenshou (auth), denshin (signaling),
  tokio, axum, serde
- **Features:** video/audio conferencing, screen sharing, recording,
  SFU architecture, room management

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

### `kindling`
Nix flake management tool. Cross-platform CLI for flake operations.

- **Language:** Rust
- **Build:** substrate `rust-tool-release-flake.nix` (4-target cross-compilation)

### `blx`
Shell extension utilities for blackmatter-shell.

- **Language:** Rust

---

## Nix Integration Patterns

### Application flake.nix (tobirato pattern)

All GPU applications follow the same flake structure:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

Shared libraries use substrate's `rust-library.nix`:

```nix
rustLibrary = import "${substrate}/lib/rust-library.nix" {
  inherit system nixpkgs;
  nixLib = substrate;
  inherit crate2nix;
};
lib = rustLibrary { name = "libname"; src = ./.; };
```

### Cargo.toml conventions

- Prefer crates.io deps: `irodori = "0.1"` (all pleme libraries are published)
- Git deps fallback: `crate = { git = "https://github.com/pleme-io/crate" }`
- Edition 2024, rust-version 1.89.0
- Release profile: `codegen-units = 1`, `lto = true`, `opt-level = "z"`, `strip = true`
- `[lints.clippy] pedantic = "warn"`
- MIT license
- All repos are PUBLIC on GitHub

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
