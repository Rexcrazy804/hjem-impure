{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption literalExpression mkRenamedOptionModule;
  inherit (lib) map pipe filter hasPrefix removePrefix concatStringsSep substring escapeRegex elemAt head;
  inherit (lib) assertMsg optional optionalString pathExists foldl attrValues isList removeSuffix match;
  inherit (lib.types) str listOf enum path nullOr raw;

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
      + (optionalString (cfg.dotsDirImpure != "") ''
        echo ""
        echo "Redirecting symlinks to dotsDirImpure"
        ${
          if symlinkFiles == ""
          then "echo 'No files to symlink'"
          else symlinkFiles
        }
      '');
  };

  relPathRegex = "(${escapeRegex (removeSuffix "/" cfg.dotsDirImpure)}|/nix/store/[^/]+)(/.+)"; # Regex matches [(dotsDirImpure or "/nix/store/<HASH>-...") "/relPath"]
  symlinkFiles = pipe cfg.parseAttrs [
    (filter (x:
      if cfg.dotsDir == null # Uses "-relink=" method if dotsDir is unset, symlinkFiles is already guarded by cfg.dotsDirImpure != ""
      then (substring 43 8 "${x.source}") == "-relink=" # /nix/store/ (11) + <HASH> (32) = 43, "-relink=" (8)
      else cfg.dotsDir != null && hasPrefix "${cfg.dotsDir}" "${x.source}"))
    # ensures that paths are valid. Throws an error if they aren't. "-relink=" method checks on the original passthru.path instead of its build store path to avoid IFD
    (filter (x: assertMsg (pathExists (if cfg.dotsDir == null then x.source.path else x.source)) "hjem-impure: the path ${x.source} DOES NOT EXIST"))
    (map (x: "symlink ${cfg.dotsDirImpure}${
      if cfg.dotsDir == null # "-relink=" method extracts the "/relPath" from elem 1 of the relPathRegex match
      then elemAt (match relPathRegex (toString x.source.path)) 1 # toString on the original passthru.path to avoid copying to store and IFD
      else removePrefix "${cfg.dotsDir}" "${x.source}"
    } ${x.target}"))
    (concatStringsSep "\n")
  ];

  replaceFiles = pipe cfg.parseAttrs [
    (filter (x:
      ! (
        if cfg.dotsDir == null
        then cfg.dotsDirImpure != "" && ((substring 43 8 "${x.source}") == "-relink=")
        else cfg.dotsDir != null && hasPrefix "${cfg.dotsDir}" "${x.source}"
      )))
    (map (x: "replace ${x.target}"))
    (concatStringsSep "\n")
  ];

  relink = path:
    if isList path # [./. "filename"] workarounds edge case of concatenating paths with illegal store path chracters such as ./. + "@filename!"
    then let path' = "/${elemAt path 1}"; in pkgs.runCommand "relink=${baseNameOf path'}" {passthru = {path = (head path) + path';};} "cp -a ${head path}${path'} $out"
    else pkgs.runCommand "relink=${baseNameOf path}" {passthru = {inherit path;};} "cp -a ${path} $out"; # relink ./pathToFile, name relink=... & embeds passthru.path
in {
  imports = [
    (mkRenamedOptionModule ["impure" "linkFiles"] ["impure" "parseAttrs"])
  ];

  options.relink = mkOption {
    type = raw;
    readOnly = true;
    internal = true;
    default = relink;
  };

  options.impure = {
    enable = mkEnableOption "hjem impure planting script";

    dotsDir = mkOption {
      type = nullOr path;
      default = null;
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
        assertion = cfg.dotsDir != null -> cfg.dotsDirImpure != "";
        message = "hjem-impure: `dotsDir` set without setting `dotsDirImpure`";
      }
      {
        assertion = cfg.dotsDir != null -> builtins.isString cfg.dotsDir;
        message = "hjem-impure: `dotsDir` must be a path wrapped in a string: \"\${./your/dots/folder}\"";
      }
    ];

    warnings = optional (cfg.dotsDirImpure != "" && symlinkFiles == "") "hjem-impure: detected zero files to symlink";
    packages = [planter];

    # When you system is `pure` $XDG_STATE_HOME/HJEM_IMPURE_ACTIVE will be 0
    xdg.state.files."HJEM_IMPURE_ACTIVE".text = "0";
  };
}
