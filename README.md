# Hjem impure
A simple hjem module that provides a script
to overwrite `/nix/store/...` links created by hjem
with relative links to your nixos configuration or a mutable copy on demand.
No more waiting for your configuration to build to test changes!

https://github.com/user-attachments/assets/3648a751-77c8-4336-b60e-19969ec27d98

### What does it do exactly?
First, hjem-impure module reads your `hjem.users.${myUserName}.xdg.config.files`
and `hjem.users.${myUserName}.files` attrsets.
(this can be modified with `impure.linkFiles` option)

Then, it populates the `hjem-impure` script to perform the following:
1. If the file/dir can be a symlink to your nixos configuration, the hjem symlinks
are replaced with symlinks to the respective file/dir in your nixos configuration
2. Otherwise if its NOT a directory, the hjem symlink is replaced with a mutable copy of the file it points to

Suppose you have the lines `xdg.config.files."hypr/hyprland.conf" = ./mydots/hyprland/hyprland.conf`
in your `/home/myuser/nixos/user.nix`.

Hjem would create a symlink at `.config/hypr/hypland.conf` to `/nix/store/98p1jnnhh146kkllrj9jfd7if5hbmqws-hyprland.conf`,
which is a path in the non-readable nix store.

When you run the `hjem-impure` script, the symlink at `.config/hypr/hyplrand.conf`
is replaced with a symlink to `/home/myuser/nixos/mydots/hyplrand/hyprland.conf`.

Pretty simple right? Its absurdly effective too!

### Installation
First, add hjem-impure to your flake inputs
```nix
{
    inputs = {
        hjem-impure.url = "github:Rexcrazy804/hjem-impure";      # inputs.nixpkgs.follows is NOT required
        # ...                                                    # ... other inputs
    };
}
```

Next, add hjem-impure as an extraModule for hjem
and enable hjem impure for your desired user
```nix
{
    hjem.extraModules = [
        inputs.hjem-impure.hjemModules.default                                  # imports the hjemModule
    ];
    hjem.users.${myUserName} = {
        impure = {
            enable = true;                                                      # enable hjem-impure
            dotsDir = "${./myDotsFolder}";                                      # pure path to dotsFolder AS STRING
            dotsDirImpure = "/home/myuser/nixos/myDotsFolder";                  # impure absolute path to dots folder
        };

        # NOTE
        # by default hjem-impure parses `files` and `xdg.config.files`
        # see `impure.linkFiles` for altering this behavior

        xdg.config.files = let
            dots = config.hjem.users.${myUserName}.impure.dotsDir;
            gnomebgs = "${pkgs.gnome-backgrounds}/share/backgrounds/gnome/";
        in {
            "hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";     # all links that you'd like to link with hjem-impure must use `dots`
            "hypr/colors.conf".text = ''                                        # files that do not use the `dots`, will be replaced with a mutable copy
                $mycoolcolor = rgba(d392fcff)
            '';
            "background".source = gnomebgs + "pills-l.jxl";                     # this applies to .source'd files as well
            "backgrounds".source = gnomebgs                                     # HOWEVER, presently, folders CANNOT be replaced with a mutable copy
        };

        # or alternatively
        files = let
            # this is repeated here but you can always use
            # a top level let in to deduplicate
            dots = config.hjem.users.${myUserName}.impure.dotsDir;
        in {
            ".config/hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";
        };
    };
}
```

### Usage
simply run the below to create the relative symlinks overwriting existing ones.
```
hjem-impure
```

The next nixos-rebuild will overwrite hjem-impure's relative links.
Alternatively you can also re-create hjem's /nix/store links using
```bash
systemd-tmpfiles --user --create
```

### Acknowledgements
- [hjem-rum](https://github.com/snugnug/hjem-rum) my reference for creating this module
- jade's [use nix less](https://jade.fyi/blog/use-nix-less/) sparked the idea for this and I've gratefully used their script as a base for `hjem-impure`
