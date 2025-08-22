{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption pipe attrValues optional;
  inherit (lib) map filter hasPrefix removePrefix concatStringsSep;
  inherit (lib.types) str;
  planter = pkgs.writeScriptBin "hjem-impure" ''
    set -euo pipefail
    function symlink() {
        if [[ -e "$2" && ! -L "$2" ]] ; then
            echo "$2 exists and is not a symlink. Ignoring it." >&2
            return 1
        fi
        mkdir -p $(dirname $2)
        ln -sfv "$1" "$2"
    }

    ${symlinkFiles}
  '';

  symlinkFiles = pipe config.impure.linkFiles [
    (filter (x: x ? source && hasPrefix "${config.impure.dotsDir}" "${x.source}"))
    (map (x: "symlink ${config.impure.dotsDirImpure}${removePrefix "${config.impure.dotsDir}" "${x.source}"} ${x.target}"))
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
      readOnly = true;
      default = config.xdg.config.files;
      description = "files to impurely link";
      apply = x: attrValues x;
    };
    # debugging only
    script = mkOption {
      readOnly = true;
      default = planter;
    };
  };
  config = mkIf config.impure.enable {
    assertions = [
      {
        assertion = config.impure.linkFiles != [];
        message = ''
          hjem impure only supports `hjem.users.${config.user}.xdg.config.files` presently.
          Please relocate your `files.".config/myprogram/*"` into `xdg.config.files."myprogram/*"`
        '';
      }
    ];
    warnings = optional (symlinkFiles == "") "hjem-impure detected zero files to symlink";
    packages = [planter];
  };
}
