{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
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
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { moduleWithSystem, ... }:
      {
        systems = [ "x86_64-linux" ];
        perSystem =
          {
            self',
            system,
            pkgs,
            ...
          }:
          {
            packages = {
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
                            inherit inputs self';
                            target = self.nixosConfigurations.deploy-pc;
                          })
                        ];
                      };
                    })
                  ];
                }).config.system.build.isoImage;

              vm-iso = pkgs.callPackage (import ./vm/iso.nix { inherit inputs self'; }) { };

              vm = self.nixosConfigurations.deploy-pc-vm.config.system.build.vmWithDisko;

              register-to-netbird = pkgs.callPackage ./register-to-netbird { };

              formatter = pkgs.nixfmt-rfc-style;
            };
          };

        flake = {

          nixosModules = {
            deploy-pc = moduleWithSystem (
              { self', ... }:
              import ./deploy-pc.nix {
                inherit inputs self';
              }
            );
          };

          nixosConfigurations = {
            deploy-pc = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                self.nixosModules.deploy-pc
              ];
            };

            deploy-pc-vm = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                self.nixosModules.deploy-pc
                ./vm/default.nix
                {
                  enableVmHardware = true;
                }
              ];
            };
          };

        };

      }
    );
}
