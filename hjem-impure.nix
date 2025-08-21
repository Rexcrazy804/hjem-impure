{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf map attrValues match concatStringsSep mkOption;
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

    ${concatStringsSep "\n" symlinkFiles}
  '';

  symlinkFiles = map (x:
    if x ? source && (match "/home.*" (builtins.toString x.source)) != null
    then "symlink ${builtins.toString x.source} ${x.target}"
    else "")
  config.impure.linkFiles;
in {
  options.impure = {
    enable = mkEnableOption "hjem impure planting script";
    linkFiles = mkOption {
      readOnly = true;
      default = config.xdg.config.files;
      description = "files to impurely link";
      apply = x: attrValues x;
    };
  };
  config = mkIf config.impure.enable {
    assertions = [
      {
        assertion = config.impure.linkFiles != [];
        message = ''
          hjem impure only supports `hjem.users.${config.user}.xdg.config.files` presently
          please relocate your `files.".config/myprogram/*"` into `xdg.config.files."myprogram/*"`
        '';
      }
    ];
    packages = [planter];
  };
}
