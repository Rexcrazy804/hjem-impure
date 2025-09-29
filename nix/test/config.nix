{
  inputs,
  self,
  ...
}: let
  dots = "${./dots}";
in {
  imports = [inputs.hjem.nixosModules.default];
  system.stateVersion = "25.05";

  users.users.kokomi = {
    isNormalUser = true;
    home = "/home/kokomi";
  };

  hjem.extraModules = [self.hjemModules.default];
  hjem.users.kokomi = {
    enable = true;
    user = "kokomi";
    impure = {
      enable = true;
      dotsDir = dots;
      dotsDirImpure = "/home/kokomi/dots";
    };
    xdg.config.files = {
      # this file should be relinked to dots/booru.toml
      "booru/config.toml".source = dots + "/booru.toml";
      # this directory should be relinked to dots/foot
      "foot".source = dots + "/foot";
      # this file should be made mutable
      "kokomi/kokomi.lua".text = ''
        print("everywhere I go, I see her face.")
      '';
      # the symlink for this directory should be replaced with a normal directory
      "uwsm".source = ./dots/uwsm;
    };
  };
}
