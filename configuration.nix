{ modulesPath
, lib
, pkgs
, config
, ...
} @ args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.git
    pkgs.fastfetch
    pkgs.vim
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      # import host keys as ssh keys
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      # this will use an age key that is already expected to be in the filesystem
      keyFile = "/var/lib/sops-nix/keys.txt";
      # if the above key is not there we create the it.
      generateKey = true;
    };

    secrets = {
      nixie_password = {
        neededForUsers = true;
      };
      "services/secret/message" = {
        owner = "nixie";
      };
    };
  };

  systemd.services."secretservice" = {
    description = "Write secret message to file";
    after = [ "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      echo "Secret path: ${config.sops.secrets."services/secret/message".path}" >> /home/nixie/secret
      echo "heres the super secret message: $(cat ${config.sops.secrets."services/secret/message".path})" >> /home/nixie/secret
    '';
    serviceConfig = {
      User = "nixie";
      WorkingDirectory = "/home/nixie";
      PermissionsStartOnly = true;
    };
  };

  users.mutableUsers = false;
  users.users.nixie = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPasswordFile = config.sops.secrets.nixie_password.path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMr8qETvTGSBHbDXiOk+QOhfRvKT0wDvOwtuMEDT+Bcc quant@quantinium.dev"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys =
    [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMr8qETvTGSBHbDXiOk+QOhfRvKT0wDvOwtuMEDT+Bcc quant@quantinium.dev"
    ];

  system.stateVersion = "25.11";
}
