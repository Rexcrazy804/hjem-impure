{
  outputs = {self, ...}: {
    hjemModules = {
      hjem-impure = ./hjem-impure.nix;
      default = self.hjemModules.hjem-impure;
    };
  };
}
