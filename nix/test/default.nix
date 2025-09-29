{
  testers,
  specialArgs,
}:
testers.runNixOSTest {
  name = "hjem-impure tests";
  node = {inherit specialArgs;};
  nodes.Dracaena_Somnolenta = import ./config.nix; # <><

  testScript = /*python*/ ''
    # preliminary hjem stuff
    # https://github.com/feel-co/hjem/blob/main/tests/basic.nix
    machine.succeed("loginctl enable-linger kokomi")
    machine.wait_until_succeeds("systemctl --user --machine=kokomi@ is-active systemd-tmpfiles-setup.service")

    # ensure hjem links
    machine.succeed("[ -L ~kokomi/.config/booru/config.toml ]")
    machine.succeed("[ -L ~kokomi/.config/kokomi/kokomi.lua ]")
    machine.succeed("[ -L ~kokomi/.config/uwsm ]")
    machine.succeed("[ -L ~kokomi/.config/foot ]")

    # copy test dots
    machine.copy_from_host("${./dots}", "/home/kokomi/dots")

    # run hjem-impure and verify files
    machine.succeed("su -- kokomi -c 'hjem-impure'")
    # ensure kokomi.lua is not a symlink and is a simple file
    machine.succeed("[ -f ~kokomi/.config/kokomi/kokomi.lua ] && [ ! -L ~kokomi/.config/kokomi/kokomi.lua ]")
    # ensure that booru/config.toml is a symlink to dots/booru.toml
    machine.succeed("[ $(realpath ~kokomi/.config/booru/config.toml) == ~kokomi/dots/booru.toml ]")
    # ensure that .config/uwsm is not a symlink but a plain directory
    machine.succeed("[ ! -L ~kokomi/.config/uwsm ] && [ -d ~kokomi/.config/uwsm ]")
    # ensure that .config/foot is a symlink to dots/foot
    machine.succeed("[ $(realpath ~kokomi/.config/foot) == ~kokomi/dots/foot ]")
    # same thing as above but check one file deeper so that kokomi can be happy
    machine.succeed("[ $(realpath ~kokomi/.config/foot/foot.ini) == ~kokomi/dots/foot/foot.ini ]")

    # my deslexic ass does not like the density of the comments above,
    # but my forgetfull ass will appreciate it later.
  '';
}
