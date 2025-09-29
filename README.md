# Hjem impure
Hjem impure provides a script which:
- Replaces every hjem symlink with writable normal files and directories
- Links particular symlinks back into your nixos configuration | [advanced installation](#advanced-installation)

No more waiting for nixos-rebuilds to modify your dots. Ever.

https://github.com/user-attachments/assets/974e4f9e-0156-4ec1-b7ca-fcf9e4eb7e5b

### Installation
First, add hjem-impure to your flake inputs
```nix
{
  inputs = {
    hjem-impure = {
      url = "github:Rexcrazy804/hjem-impure";
      # these are only required for internal tests,
      # hence you can set em to nothing
      inputs.nixpkgs.follows = "";
      inputs.hjem.follows = "";
    };
  };
}
```

Next, add hjem-impure as an extraModule for hjem
and enable hjem impure for your desired user
```nix
# assuming that you pass inputs as specialArgs
{inputs, ...}:
{
  # imports the hjemModule
  hjem.extraModules = [inputs.hjem-impure.hjemModules.default];
  # enable hjem-impure
  hjem.users.${myUserName}.impure.enable = true;
}
```

And that's it, after you rebuild your configuraiton
you should have the `hjem-impure` executable.

### Advanced Installation
Hjem impure offers the ability to optionally relink certain symlinks created by hjem
back into your nixos configuration,
granted that there exists a common dotsDir from which each file/dir is `source`'d

```nix
{config, ...}:
{
  hjem.users.${myUserName} = {
    impure = {
	  # enable hjem-impure
      enable = true;
	  # pure path to dotsFolder AS STRING
      dotsDir = "${./myDotsFolder}";
	  # impure absolute path to dots folder
      dotsDirImpure = "/home/myuser/nixos/myDotsFolder";
    };

    xdg.config.files = let
	  # aforementioned common dots
      dots = config.hjem.users.${myUserName}.impure.dotsDir;
    in {
	  # it is a requirement to use `dots` for the relinking feature
      "hypr/hyprland.conf".source = dots + "/hyprland/hyprland.conf";
      "hypr/hypridle.conf".source = dots + "/hyprland/hypridle.conf";
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
Alternatively you can also re-create hjem's immutable links using
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
