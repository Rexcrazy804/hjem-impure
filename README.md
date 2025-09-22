# Hjem impure
Hjem impure provides a script which:
- Replaces every hjem symlink with writable normal files and directories
- Links particular symlinks back into your nixos configuration **(requires advanced config)**

No more waiting for nixos-rebuilds to modify your dots. Ever.

https://github.com/user-attachments/assets/974e4f9e-0156-4ec1-b7ca-fcf9e4eb7e5b

### Installation
First, add hjem-impure to your flake inputs
```nix
{
  inputs = {
    hjem-impure.url = "github:Rexcrazy804/hjem-impure";      # inputs.nixpkgs.follows NOT required
    # ...                                                    # ... other inputs
  };
}
```

Next, add hjem-impure as an extraModule for hjem
and enable hjem impure for your desired user
```nix
{inputs, ...}:                                              # assuming that you pass inputs as specialArgs
{
  hjem.extraModules = [
    inputs.hjem-impure.hjemModules.default                  # imports the hjemModule
  ];
  hjem.users.${myUserName}.impure.enable = true;            # enable hjem-impure
}
```

And that's it, after you rebuild your configuraiton
you should have the `hjem-impure` executable.

### Advanced Installation
Hjem impure offers the ability to optionally relink certain symlinks created by hjem
back into your nixos configuration,
granted that there exists a common dotsDir from which each file/dir is `source`'d

```nix
{
  hjem.users.${myUserName} = {
    impure = {
      enable = true;                                                      # enable hjem-impure
      dotsDir = "${./myDotsFolder}";                                      # pure path to dotsFolder AS STRING
      dotsDirImpure = "/home/myuser/nixos/myDotsFolder";                  # impure absolute path to dots folder
    };

    # NOTE
    # by default hjem-impure parses your `files` and `xdg.*.files`
    # see `impure.parseAttrs` for altering this behavior

    xdg.config.files = let
      dots = config.hjem.users.${myUserName}.impure.dotsDir;              # aforementioned commond dots
    in {
      "hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";     # use `dots` for overwriting with symlinks to nixos configuration
      "hypr/hypridle.conf".source = dots + "/hyprland/hypridle.conf";     # use `dots` for overwriting with symlinks to nixos configuration
    };

    # or alternatively
    files = let
      # this is repeated here but you can always use
      # a top level let in to deduplicate
      dots = config.hjem.users.${myUserName}.impure.dotsDir;
    in {
      ".config/hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";
      ".config/hypr/hypridle.conf".source = dots + "/hyprland/hypridle.conf";
    };
  };
}
```

for a fleshed out configuration and flake example see [zaphkieltest](https://github.com/Rexcrazy804/zaphkieltest/blob/master/configuration.nix#L31C1-L50)

### Usage
simply run the below to make your hjem links modifiable
and if configured, overwrite with symlinks to your nixos configuration.
```
hjem-impure
```

The next nixos-rebuild will overwrite hjem-impure's changes.
Alternatively you can also re-create hjem's `/nix/store` links using
```bash
systemd-tmpfiles --user --create
```

or if you use smfh as the linker
```bash
systemctl start hjem-activate@userName.service
```

### How does it work exactly?
hjem impure module simply reads information hjem uses to plant files in place. 
This information is converted into a shell script
that either replaces the symlinks with symlinks to the nixos configuration,
or makes a writable copy of the file or directory.

### Acknowledgements
- [hjem-rum](https://github.com/snugnug/hjem-rum) my reference for creating this module
- jade's [use nix less](https://jade.fyi/blog/use-nix-less/) sparked the idea for this and I've gratefully used their script as a base for `hjem-impure`
