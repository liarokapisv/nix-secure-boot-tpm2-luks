{
  inputs,
}:
inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./disko.nix
    "${inputs.nixpkgs}/nixos/modules/profiles/all-hardware.nix"
    (
      {
        pkgs,
        lib,
        ...
      }:
      {
        nix.settings.experimental-features = [
          "nix-command"
          "flakes"
        ];

        networking.hostName = "nixos-target";
        services.getty.autologinUser = "root";

        # needed for auto-unlock
        boot.initrd.systemd.enable = true;
        boot.initrd.systemd.tpm2.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;

        # good to have on userspace
        security.tpm2 = {
          enable = true;
          pkcs11.enable = true;
          tctiEnvironment.enable = true;
        };

        environment.shellAliases.secure-boot-enroll = "sbctl enroll-keys --microsoft";
        environment.shellAliases.tpm2-cryptenroll = "systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000 --wipe-slot=tpm2 /dev/disk/by-partlabel/disk-main-root";

        environment.systemPackages = with pkgs; [
          sbctl
          tpm2-tools
        ];

        system.stateVersion = "25.11";

        boot.loader.systemd-boot.enable = lib.mkForce false;

        boot.lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
        };
      }
    )
  ];
}
