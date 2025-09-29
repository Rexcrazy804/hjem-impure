{
  outputs = {self, ...}: {
    hjemModules = {
      hjem-impure = ./nix/module.nix;
      default = self.hjemModules.hjem-impure;
    };
  };
}
