{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption literalExpression mkRenamedOptionModule;
  inherit (lib) map pipe filter hasPrefix removePrefix concatStringsSep;
  inherit (lib) assertMsg optional optionalString pathExists foldl attrValues;
  inherit (lib.types) str listOf enum;

  cfg = config.impure;
  hjemFileAttrList = [
    config.files
    config.xdg.config.files
    config.xdg.data.files
    config.xdg.state.files
    config.xdg.cache.files
  ];

  planter = pkgs.writeShellApplication {
    name = "hjem-impure";
    text = ''
        # avoids running hjem-impure if system is already impure
        IMPURE_ACTIVE_FILE="${config.xdg.state.files.HJEM_IMPURE_ACTIVE.target}" 
        if [[ -f  "$IMPURE_ACTIVE_FILE" && $(cat "$IMPURE_ACTIVE_FILE") -eq 1 ]]; then
          echo "Re-run not required, already impure."
          echo "See: https://github.com/Rexcrazy804/hjem-impure?tab=readme-ov-file#usage"
          exit 0
        fi

        function symlink() {
          if [[ -e "$2" && ! -L "$2" ]] ; then
            echo "$2 exists and is not a symlink. Ignoring it." >&2
            return 0
          fi
          # prevents ln failing for symlinks that are directories
          if [[ -d "$2" ]] ; then
            rm "$2"
          fi

          mkdir -p "$(dirname "$2")"
          ln -sfv "$1" "$2"
        }

        function replace() {
          if [[ -d "$1" ]] ; then
            if [[ ! -L "$1" ]] ; then
              echo "$1 exists and is not a symlink. Ignoring it." >&2
              return 0
            fi
            STORE_PATH=$(realpath "$1")
            rm "$1"
            cp -rL --no-preserve=all "$STORE_PATH" "$1"
          else
            # for more info: https://stackoverflow.com/a/12673543
            ${pkgs.gnused}/bin/sed -i "" "$1"
            chmod u+w "$1"
          fi
          echo "$1"
        }

        echo "Replacing symlinks with mutable copies"
        ${
          if replaceFiles == ""
          then "echo 'No files to replace'"
          else replaceFiles
        }

        echo 1 > "$IMPURE_ACTIVE_FILE" || echo "[INFO] Unable to write to $IMPURE_ACTIVE_FILE"
      ''
      + (optionalString (cfg.dotsDir != "") ''
        echo ""
        echo "Redirecting symlinks to dotsDirImpure"
        ${
          if symlinkFiles == ""
          then "echo 'No files to symlink'"
          else symlinkFiles
        }
      '');
  };

  symlinkFiles = pipe cfg.parseAttrs [
    (filter (x: cfg.dotsDir != "" && hasPrefix "${cfg.dotsDir}" "${x.source}"))
    # ensures that paths are valid. Throws an error if they aren't
    (filter (x: assertMsg (pathExists x.source) "hjem-impure: the path ${x.source} DOES NOT EXIST"))
    (map (x: "symlink ${cfg.dotsDirImpure}${removePrefix "${cfg.dotsDir}" "${x.source}"} ${x.target}"))
    (concatStringsSep "\n")
  ];

  replaceFiles = pipe cfg.parseAttrs [
    (filter (x: ! (cfg.dotsDir != "" && hasPrefix "${cfg.dotsDir}" "${x.source}")))
    (map (x: "replace ${x.target}"))
    (concatStringsSep "\n")
  ];
in {
  imports = [
    (mkRenamedOptionModule ["impure" "linkFiles"] ["impure" "parseAttrs"])
  ];

  options.impure = {
    enable = mkEnableOption "hjem impure planting script";

    dotsDir = mkOption {
      type = str;
      default = "";
      description = "directory containing your dots";
    };
    dotsDirImpure = mkOption {
      type = str;
      default = "";
      description = "string path of dotsDir";
      example = "{file}`/home/bobrose/myNixosConfig/`";
    };

    parseAttrs = mkOption {
      type = listOf (enum hjemFileAttrList);
      default = hjemFileAttrList;
      defaultText = literalExpression ''
        [
          {option}`config.files`
          {option}`config.xdg.config.files`
          {option}`config.xdg.data.files`
          {option}`config.xdg.state.files`
          {option}`config.xdg.cache.files`
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
    assertions = [
      {
        assertion = cfg.dotsDir != "" -> cfg.dotsDirImpure != "";
        message = "hjem-impure: `dotsDir` set without setting `dotsDirImpure`";
      }
    ];

    warnings = optional (cfg.dotsDir != "" && symlinkFiles == "") "hjem-impure detected zero files to symlink";
    packages = [planter];

    # When you system is `pure` $XDG_STATE_HOME/HJEM_IMPURE_ACTIVE will be 0
    xdg.state.files."HJEM_IMPURE_ACTIVE".text = "0";
  };
}
