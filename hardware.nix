{
  inputs,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    ./disko.nix
    "${inputs.nixpkgs}/nixos/modules/profiles/all-hardware.nix"
  ];
  options.enableVmHardware = lib.mkEnableOption "Enables hardware suitable for non-secure-boot vm";
  config = {
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.tpm2.enable = true;

    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.enable = lib.mkForce config.enableVmHardware;
    boot.lanzaboote = {
      enable = !config.enableVmHardware;
      pkiBundle = "/var/lib/sbctl";
    };

    ## Only uncomment for debugging in initrd stage.

    # boot.initrd.systemd.emergencyAccess = true;
    # boot.initrd.systemd.storePaths = [
    #   inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.tpm2-pcr7-measurements
    #   pkgs.tpm2-tools
    #   pkgs.sbctl
    # ];
    # boot.initrd.systemd.initrdBin = [
    #   inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.tpm2-pcr7-measurements
    #   pkgs.tpm2-tools
    #   pkgs.sbctl
    # ];
  };
}
