{
  # Realistically hjem-impure, the module, does not depend on any of these inputs.
  # However, untested software depreives me of sound sleep.
  # So for the sake of our common welfare,
  # we pull these flakes and run some tests

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hjem.url = "github:feel-co/hjem";
    hjem.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) genAttrs nixosSystem;

    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    pkgsOf = nixpkgs.legacyPackages;
    eachSystem = genAttrs systems;
    specialArgs = {inherit inputs self;};
  in {
    checks = eachSystem (system: {
      hjem-test = pkgsOf.${system}.callPackage ./nix/test {inherit specialArgs;};
    });

    hjemModules = {
      hjem-impure = ./nix/module.nix;
      default = self.hjemModules.hjem-impure;
    };

    # $ nixos-rebuild --flake .#testVm build-vm
    # $ ./result/bin/run-nixos-vm
    nixosConfigurations.testVm = nixosSystem {
      system = "x86_64-linux";
      inherit specialArgs;
      modules = [
        ./nix/test/config.nix
        ({modulesPath, ...}: {
          imports = [
            (modulesPath + "/profiles/qemu-guest.nix")
            (modulesPath + "/virtualisation/qemu-vm.nix")
          ];

          virtualisation.graphics = false;
          users.users.kokomi.initialPassword = "kokomi";
          hjem.users.kokomi.clobberFiles = true;
        })
      ];
    };
  };
}
