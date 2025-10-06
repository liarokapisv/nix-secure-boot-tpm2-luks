{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = {
        installer-iso =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              (import ./installer-iso.nix {
                target = self.nixosConfigurations.deploy-pc;
              })
            ];
          }).config.system.build.isoImage;

        run-vm = nixpkgs.legacyPackages.${system}.callPackage (import ./run-vm.nix { inherit inputs; }) { };
      };

      nixosConfigurations.deploy-pc = import ./deploy-pc.nix {
        inherit inputs;
      };
    };
}
