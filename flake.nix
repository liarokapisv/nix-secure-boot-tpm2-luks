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
      pkgs = nixpkgs.legacyPackages.${system};
      deploy-pc-module = import ./deploy-pc.nix {
        inherit inputs;
      };
    in
    {
      packages.${system} = {
        iso =
          (nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              (import ./installer-pre.nix {
                target = nixpkgs.lib.nixosSystem {
                  inherit system;
                  modules = [
                    (import ./installer-post.nix {
                      inherit inputs;
                      target = self.nixosConfigurations.deploy-pc;
                    })
                  ];
                };
              })
            ];
          }).config.system.build.isoImage;

        vm-iso = pkgs.callPackage (import ./vm/iso.nix { inherit inputs; }) { };

        vm = self.nixosConfigurations.deploy-pc-vm.config.system.build.vmWithDisko;

        register-to-netbird = pkgs.callPackage ./register-to-netbird { };
      };

      nixosConfigurations.deploy-pc = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          deploy-pc-module
        ];
      };

      nixosConfigurations.deploy-pc-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          deploy-pc-module
          ./vm/default.nix
          {
            enableVmHardware = true;
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;

    };
}
