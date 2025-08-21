# Hjem impure
A simple hjem module that provides a script 
to overwrite `/nix/store/...` links created by hjem 
with relative links to your nixos configuration on demand.
No more waiting for your configuration to build to test changes!

### What does it do exactly?
hjem-impure reads your `hjem.users.${myUserName}.xdg.config.files` attrset 
and filters through it to identify config files that are simply links
to your nixos configuration directory. For instance

```
xdg.config.files."hypr/hyprland.conf" = ./mydots/hyprland/hyprland.conf
```

with this information, a script `hjem-impure` is created 
that effectively overwrites the /nix/store link hjem creates
into relative links to your nixos configuration

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
```nix
{
    hjem.extraModules = [inputs.hjem-impure.hjemModules.default];
}
```

Finally, enable hjem impure for your desired user

```nix
{
    hjem.users.${myUserName}.impure.enable = true;
}
```

### Usage
simple run `hjem-impure` to create the relative symlinks overwriting existing ones.
The next nixos-rebuild will overwrite hjem-impure's relative links.
Alternatively you can also re-create hjem's /nix/store links using
```bash
systemd-tmpfiles --user --create
```

### Acknowledgements
[hjem-rum](https://github.com/snugnug/hjem-rum) my reference for creating this module
