{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.deploy-rs.url = "github:serokell/deploy-rs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { self
    , nixpkgs
    , disko
    , deploy-rs
    , sops-nix
    , ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      deployPkgs = import nixpkgs {
        inherit system;
        overlays = [
          deploy-rs.overlays.default
          (self: super: { deploy-rs = { inherit (pkgs) deploy-rs; lib = super.deploy-rs.lib; }; })
        ];
      };
    in
    {
      nixosConfigurations.digitalocean = nixpkgs.lib.nixosSystem {
        system = system;
        modules = [
          ./digitalocean.nix
          disko.nixosModules.disko
          { disko.devices.disk.disk1.device = "/dev/vda"; }
          ./configuration.nix
          sops-nix.nixosModules.sops
        ];
      };

      deploy.nodes = {
        digitalocean = {
          hostname = "nixos";
          fastConnection = true;
          profiles = {
            system = {
              sshUser = "root";
              user = "root";
              path = deployPkgs.deploy-rs.lib.activate.nixos self.nixosConfigurations.digitalocean;
            };
          };
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
