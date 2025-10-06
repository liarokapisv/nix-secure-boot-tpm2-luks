{
  inputs,
}:
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (import ./fixed.nix { inherit inputs; })
  ];

  nix = {
    settings = {
      auto-optimise-store = true;
      trusted-users = [ "@wheel" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than +3";
    };
  };

  boot.tmp.cleanOnBoot = true;

  networking.hostName = "acu-deploy-pc";

  users = {
    mutableUsers = true;
    users = {
      deploy = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "dialout"
        ];
        initialHashedPassword = "$y$j9T$1EZgT76hzkTtVuaV6VvHT/$wpWt5Q0Ktx0bQN6A4misV/i/dxRackf9bdC7S7noKvD";
      };
    };
  };

  services = {
    getty.autologinUser = "deploy";
    userborn.enable = true;
  };

  # good to have on userspace
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  environment.systemPackages = with pkgs; [
    hello
    sbctl
    tpm2-tools
    git
    wget
    ltrace
    usbutils
    tmux
  ];

  programs = {
    nix-ld.enable = true;
    zsh.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    fuse.userAllowOther = true;
    htop.enable = true;
  };

  system.stateVersion = "25.11";
}
