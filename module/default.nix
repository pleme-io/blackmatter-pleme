{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.blackmatter.components.pleme;
  skillsDir = ../skills;
  bundledSkillNames =
    if builtins.pathExists skillsDir
    then builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsDir))
    else [];
  bundledSkillFiles = lib.listToAttrs (map (name:
    lib.nameValuePair name (skillsDir + "/${name}/SKILL.md")
  ) bundledSkillNames);
  allSkillFiles = bundledSkillFiles // cfg.skills.extraSkills;
in {
  options.blackmatter.components.pleme = {
    enable = mkEnableOption "Pleme-io org conventions and skills";
    skills = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Deploy pleme-io skills to ~/.claude/skills/";
      };
      extraSkills = mkOption {
        type = types.attrsOf types.path;
        default = {};
        description = "Additional skill files. Keys are skill names, values are SKILL.md paths.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.skills.enable && allSkillFiles != {}) {
    home.file = lib.mapAttrs' (name: path:
      lib.nameValuePair ".claude/skills/${name}/SKILL.md" {
        source = path;
      }
    ) allSkillFiles;
  };
}
