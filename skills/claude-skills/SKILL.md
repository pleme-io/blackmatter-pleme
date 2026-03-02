---
name: claude-skills
description: Create, update, and maintain Claude Code skills in the blackmatter-claude repo. Use when adding a new skill, modifying an existing skill, or understanding how skills are authored and deployed to the user's system via the Nix home-manager module.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "2.0.0"
  last_verified: "2026-03-01"
  domain_keywords:
    - "skill"
    - "claude"
    - "SKILL.md"
    - "blackmatter-claude"
---

# Claude Code Skills — Authoring & Maintenance

## Architecture

Skills live in the `blackmatter-claude` repo and are deployed to every machine via Nix home-manager.

```
blackmatter-claude/
  skills/
    {skill-name}/
      SKILL.md          ← one file per skill
  module/
    default.nix         ← HM module (auto-discovers skills/)
```

The HM module auto-discovers every subdirectory under `skills/` at evaluation time:

```nix
skillsDir = ../skills;
bundledSkillNames = builtins.attrNames (
  lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsDir)
);
```

Each discovered skill is symlinked to `~/.claude/skills/{name}/SKILL.md` on rebuild.

## Deployment Pipeline

### Bundled skills (generic, in blackmatter-claude)

```
blackmatter-claude repo   (author skill here)
        ↓  git push
nix repo                  (nix flake update blackmatter-claude)
        ↓  darwin-rebuild
~/.claude/skills/         (skill available to Claude Code)
```

After pushing a new or updated bundled skill:

```bash
# 1. Push blackmatter-claude
cd ~/code/github/pleme-io/blackmatter-claude
git add skills/{name}/SKILL.md
git commit -m "feat: add {name} skill"
git push

# 2. Update nix to pick up new commit
cd ~/code/github/pleme-io/nix
nix flake update blackmatter-claude
git add flake.lock && git commit -m "chore: update blackmatter-claude" && git push

# 3. Rebuild to deploy
nix run .#darwin-rebuild
```

### Org-specific skills (in blackmatter-pleme)

```
blackmatter-pleme repo   skills/{name}/SKILL.md  (author skill here)
        ↓  git push
nix repo                  (nix flake update blackmatter-pleme)
        ↓  rebuild
~/.claude/skills/         (skill available to Claude Code)
```

Same deployment flow as bundled skills — push, flake update, rebuild.

## SKILL.md Format

Every skill file has YAML front matter followed by markdown content.

### Front Matter (required)

```yaml
---
name: {skill-name}
description: {One sentence. Start with a verb. Describe WHEN to use this skill — Claude Code matches skills to user intent using this field.}
allowed-tools: {comma-separated tool names the skill may use}
metadata:
  version: "1.0.0"
  last_verified: "{YYYY-MM-DD}"
---
```

### Front Matter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Lowercase, hyphenated identifier. Must match the directory name. |
| `description` | yes | Trigger sentence — Claude Code uses this to decide when to invoke the skill. Start with a verb, include "Use when..." clause. |
| `allowed-tools` | yes | Tools the skill is permitted to call. Common sets: `Bash, Read` (read-only ops), `Read, Write, Edit, Glob, Grep, Bash` (full file ops). |
| `metadata.version` | yes | SemVer string. Bump on content changes. |
| `metadata.last_verified` | yes | Date the skill was last tested/verified. |
| `metadata.domain_keywords` | no | List of strings for additional matching hints. |

### Body Content

The markdown body is the skill's knowledge — instructions, templates, checklists, reference material. Write it as if briefing an agent who has never seen the codebase.

**Structure guidelines:**

1. **Pre-flight / Context** — What to check before acting
2. **Reference material** — Templates, patterns, conventions, directory layouts
3. **Step-by-step procedures** — Concrete workflows with code blocks
4. **Constraints / Anti-patterns** — What NOT to do
5. **Validation checklist** — How to verify the work

Use fenced code blocks with language tags. Prefer concrete examples over abstract descriptions.

## Naming Conventions

- Directory name = skill name = `name` field in front matter
- Lowercase, hyphenated: `helm-k8s-charts`, `pleme-flake-update`
- Descriptive but concise (2-4 words)

## Allowed Tools Reference

| Tool | When to include |
|------|-----------------|
| `Read` | Skill needs to read files |
| `Write` | Skill creates new files |
| `Edit` | Skill modifies existing files |
| `Glob` | Skill searches for files by pattern |
| `Grep` | Skill searches file contents |
| `Bash` | Skill runs shell commands |

Only include tools the skill actually needs. Fewer tools = tighter scope = safer execution.

## Adding a New Skill

### Bundled (in blackmatter-claude, shared publicly)

1. Create the directory and file:

```bash
mkdir -p ~/code/github/pleme-io/blackmatter-claude/skills/{skill-name}
```

2. Write `SKILL.md` with front matter + body content.

3. Verify the directory is discoverable:

```bash
ls ~/code/github/pleme-io/blackmatter-claude/skills/
# Should show the new directory alongside existing skills
```

4. Commit, push, update nix, rebuild (see Deployment Pipeline above).

### Org-specific (in blackmatter-pleme)

1. Create the directory and file:

```bash
mkdir -p ~/code/github/pleme-io/blackmatter-pleme/skills/{skill-name}
```

2. Write `SKILL.md` with front matter + body content.

3. The module auto-discovers skills — just commit, push, flake update, rebuild.

## Updating an Existing Skill

1. Edit the SKILL.md file.
2. Bump `metadata.version` and update `metadata.last_verified`.
3. For bundled: commit → push → flake update → rebuild.
4. For extra: commit → rebuild.

## Skill Repos

| Repo | Content | Audience |
|------|---------|----------|
| `blackmatter-claude` | Generic Claude Code skills (tool-agnostic) | All users |
| `blackmatter-pleme` | Pleme-io org-specific skills (substrate, flake chain, helm, workspace) | Pleme-io developers |
| `nix` (via `extraSkills`) | Private/user-specific skills | Single user |

For private skills, use the `extraSkills` option in the relevant module:

```nix
blackmatter.components.claude.skills.extraSkills = {
  my-private-skill = ./skills/my-private-skill/SKILL.md;
};
# or
blackmatter.components.pleme.skills.extraSkills = {
  my-org-private-skill = ./skills/my-org-private-skill/SKILL.md;
};
```

These merge with bundled skills at evaluation time and deploy to the same `~/.claude/skills/` directory.

## Anti-Patterns

- **Never put skills directly in `~/.claude/skills/`** — they'll be overwritten on rebuild. All skills go through the Nix pipeline.
- **Never put user-specific data in bundled skills** — blackmatter-claude and blackmatter-pleme are public. Use `extraSkills` in the nix repo for private content.
- **Never omit the description** — it's the primary matching signal. A skill without a good description won't be invoked.
- **Never use generic names** — `utils`, `helper`, `misc` give Claude Code no matching signal.
- **Never duplicate a CLAUDE.md concern** — skills are for procedural knowledge (how to do X). Static project context belongs in CLAUDE.md files.
