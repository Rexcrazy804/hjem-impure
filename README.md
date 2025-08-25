# Hjem impure
Hjem impure provides a script which:
- Replaces every hjem symlink with writable normal files and directories
- Links particular symlinks back into your nixos configuration

No more waiting for nixos-rebuilds to modify your dots. Ever.

https://github.com/user-attachments/assets/974e4f9e-0156-4ec1-b7ca-fcf9e4eb7e5b

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

            # you can skip setting the below if you don't require
            # rewriting hjem symlinks with symlinks to your nixos configuration
            dotsDir = "${./myDotsFolder}";                                      # pure path to dotsFolder AS STRING
            dotsDirImpure = "/home/myuser/nixos/myDotsFolder";                  # impure absolute path to dots folder
        };

        # NOTE
        # by default hjem-impure parses `files` and `xdg.config.files`
        # see `impure.linkFiles` for altering this behavior

        xdg.config.files = let
            dots = config.hjem.users.${myUserName}.impure.dotsDir;              # only required for rewriting links to nixos configuration feature
            gnomebgs = "${pkgs.gnome-backgrounds}/share/backgrounds/gnome";
        in {
            "hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";     # use `dots` for overwriting with symlinks to nixos configuration
            "hypr/colors.conf".text = ''                                        # files that do not use the `dots`, will be replaced with a mutable copy
                $mycoolcolor = rgba(d392fcff)
            '';
            "background".source = gnomebgs + "/pills-l.jxl";                    # this applies to .source'd files as well
            "backgrounds".source = gnomebgs                                     # AND DIRECTORIES!!!
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

### How does it do it exactly?
hjem impure module simply reads information hjem uses to plant files in place. 
This information is converted into a shell script
that either replaces the symlinks with symlinks to the nixos configuration,
or makes a writable copy of the file or directory.

### Acknowledgements
- [hjem-rum](https://github.com/snugnug/hjem-rum) my reference for creating this module
- jade's [use nix less](https://jade.fyi/blog/use-nix-less/) sparked the idea for this and I've gratefully used their script as a base for `hjem-impure`
