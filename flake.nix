{
  # Realistically hjem-impure, the module, does not depend on any of these inputs.
  # However, untested software depreives me of sound sleep.
  # So for the sake of our common welfare,
  # we pull these flakes and run some tests

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hjem.url = "github:feel-co/hjem";

    hjem.inputs.nixpkgs.follows = "nixpkgs";
    hjem.inputs.smfh.follows = "";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) getAttrs mapAttrs;
    pkgsFor = getAttrs ["x86_64-linux" "aarch64-linux"] nixpkgs.legacyPackages;
    eachSystem = fn: mapAttrs fn pkgsFor;
  in {
    checks = eachSystem (_: pkgs: {
      hjem-test = pkgs.callPackage ./nix/test {
        specialArgs = {inherit inputs self;};
      };
    });

    hjemModules = {
      hjem-impure = ./nix/module.nix;
      default = self.hjemModules.hjem-impure;
    };
  };
}
