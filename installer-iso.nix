{
  target,
}:
{
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  targetSystem = target.config.system.build.toplevel;
  diskoScript = target.config.system.build.diskoScript;
  closureInfo = pkgs.closureInfo {
    rootPaths = [
      targetSystem
      diskoScript
    ];
  };

  diskPrepare = pkgs.writeShellApplication {
    name = "disk-prepare";
    runtimeInputs = with pkgs; [
      util-linux
      coreutils
      gnused
      gnugrep
      gawk
    ];
    text = ''
      echo "Formatting disks.."
      echo
      echo "Select a disk (or 'q' to quit):"
      lsblk -d -n -o NAME,SIZE,MODEL | nl
      echo
      while true; do
        read -r -p "> " CHOICE
        case "$CHOICE" in
          q|Q)
            echo "Cancelled."
            exit 1
            ;;
          *)
            DISK_NAME="$(lsblk -d -n -o NAME | sed -n "''${CHOICE}p")"
            if [ -n "$DISK_NAME" ]; then
              DISK_PATH="/dev/$DISK_NAME"
              read -r -p "Use $DISK_PATH? This will destroy all data on the disk [y/N]: " CONFIRM
              [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ] || continue
              break
            else
              echo "Invalid selection! Try again."
            fi
            ;;
        esac
      done

      TEMP_DISKO="$(mktemp)"
      trap 'rm -f "$TEMP_DISKO"' EXIT

      sed "s|/DISK_PLACEHOLDER|$DISK_PATH|g" ${diskoScript} > "$TEMP_DISKO"
      chmod +x "$TEMP_DISKO"
      "$TEMP_DISKO"
    '';
  };

  lanzabootPrepare = pkgs.writeShellApplication {
    name = "lanzaboote-prepare";
    runtimeInputs = with pkgs; [
      sbctl
    ];
    text = ''
      echo "Installing Secure Boot keys..."
      sbctl create-keys --disable-landlock -d /mnt/var/lib/sbctl/GUID -e /mnt/var/lib/sbctl/keys

      echo "Piggyback on sd-boot boot entries...";
      bootctl --esp-path /mnt/boot install

    '';
  };

  systemInstall = pkgs.writeShellApplication {
    name = "system-install";
    text = ''
      echo ""
      echo "Checking disk space before installation..."
      df -h /mnt || true
      df -h /  || true
      echo ""

      echo "Installing pre-built system..."

      PATH=$PATH:/run/current-system/sw/bin
      nixos-install --system ${targetSystem} --no-root-passwd --no-channel-copy
    '';
  };

  rebootPrompt = pkgs.writeShellApplication {
    name = "reboot-prompt";
    text = ''
      echo ""
      echo "============================================"
      echo "  Installation successful!"
      echo "  You can now reboot into your new system."
      echo "============================================"
      echo ""
      printf "Reboot now? (y/n): "
      read -r REBOOT
      if [ "$REBOOT" = "y" ] || [ "$REBOOT" = "Y" ]; then
        echo "Rebooting..."
        reboot
      else
        echo "Please reboot manually when ready."
      fi
    '';
  };

  fullInstall = pkgs.writeShellApplication {
    name = "full-install";
    runtimeInputs = [
      diskPrepare
      systemInstall
      lanzabootPrepare
      rebootPrompt
    ];
    text = ''
      disk-prepare && lanzaboote-prepare && system-install && reboot-prompt
    '';
  };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.systemd-boot.enable = true;
  services.getty.autologinUser = lib.mkForce "root";
  environment.loginShellInit = ''
    if [ ! -f /tmp/.run-once ]; then
        touch /tmp/.run-once
        full-install
    fi
  '';

  environment.systemPackages = [
    diskPrepare
    lanzabootPrepare
    systemInstall
    rebootPrompt
    fullInstall
    pkgs.disko
    pkgs.tpm2-tools
    pkgs.tpm2-tss
  ];

  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  # Optional: faster ISO squash
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
