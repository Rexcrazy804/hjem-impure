{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption pipe attrValues optional literalExpression;
  inherit (lib) map filter hasPrefix removePrefix concatStringsSep;
  inherit (lib) assertMsg pathExists foldl;
  inherit (lib.types) str listOf enum;

  cfg = config.impure;

  planter = pkgs.writeShellApplication {
    name = "hjem-impure";
    text = ''
      function symlink() {
          if [[ -e "$2" && ! -L "$2" ]] ; then
              echo "$2 exists and is not a symlink. Ignoring it." >&2
              return 1
          fi
          mkdir -p $(dirname $2)
          ln -sfv "$1" "$2"
      }

      ${
        if symlinkFiles == ""
        then "echo 'No files to symlink'"
        else symlinkFiles
      }
    '';
  };

  symlinkFiles = pipe cfg.linkFiles [
    (filter (x: x ? source && hasPrefix "${cfg.dotsDir}" "${x.source}"))
    # ensures that paths are valid.
    # Throws an error if they aren't
    (filter (x: assertMsg (pathExists x.source) "hjem-impure: the path ${x.source} DOES NOT EXIST"))
    (map (x: "symlink ${cfg.dotsDirImpure}${removePrefix "${cfg.dotsDir}" "${x.source}"} ${x.target}"))
    (concatStringsSep "\n")
  ];
in {
  options.impure = {
    enable = mkEnableOption "hjem impure planting script";

    dotsDir = mkOption {
      type = str;
      description = "directory containing your dots";
    };
    dotsDirImpure = mkOption {
      type = str;
      description = "string path of dotsDir";
      example = "/home/bobrose/myNixosConfig/";
    };

    linkFiles = mkOption {
      # TODO: should this be relaxed?
      type = listOf (enum [
        config.files
        config.xdg.config.files
        config.xdg.data.files
        config.xdg.state.files
        config.xdg.cache.files
      ]);
      default = [
        config.xdg.config.files
        config.files
      ];
      defaultText = literalExpression ''
        [
          {option}`config.xdg.config.files`
          {option}`config.files`
        ];
      '';
      description = "list of attrbute sets to parse files from";
      example = literalExpression ''
        [
          hjem.users.''${userName}.xdg.config.files
          hjem.users.''${userName}.xdg.data.files
        ]
      '';
      apply = x: foldl (acc: curr: acc ++ (attrValues curr)) [] x;
    };

    # debugging only
    script = mkOption {
      readOnly = true;
      default = planter;
    };
  };
  config = mkIf cfg.enable {
    warnings = optional (symlinkFiles == "") "hjem-impure detected zero files to symlink";
    packages = [planter];
  };
}
