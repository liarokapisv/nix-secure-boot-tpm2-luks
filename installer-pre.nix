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

in
{
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

    pkgs.sbctl
    pkgs.util-linux
    pkgs.coreutils
    pkgs.gnused
    pkgs.gnugrep
    pkgs.gawk
    pkgs.disko
    pkgs.tpm2-tools
    pkgs.tpm2-tss

    (pkgs.writeShellApplication {
      name = "lanzaboote-prepare";
      text = ''
        echo "Installing Secure Boot keys..."
        sbctl create-keys --disable-landlock -d /mnt/var/lib/sbctl/GUID -e /mnt/var/lib/sbctl/keys

        echo "Piggyback on sd-boot boot entries...";
        bootctl --esp-path /mnt/boot install

      '';
    })

    (pkgs.writeShellApplication {
      name = "disk-prepare";
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

        # empty password to help provisioning - will be removed in the post installer.
        touch /tmp/empty
        cryptsetup luksAddKey /dev/disk/by-partlabel/disk-main-root --new-keyfile=/tmp/empty
      '';
    })

    (pkgs.writeShellApplication {
      name = "lanzaboote-prepare";
      text = ''
        echo "Installing Secure Boot keys..."
        sbctl create-keys --disable-landlock -d /mnt/var/lib/sbctl/GUID -e /mnt/var/lib/sbctl/keys

        echo "Piggyback on sd-boot boot entries...";
        bootctl --esp-path /mnt/boot install

      '';
    })

    (pkgs.writeShellApplication {
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
    })

    (pkgs.writeShellApplication {
      name = "secure-boot-kickstart";
      text = ''
        echo "Kickstarting secure boot automation..."
        mkdir -p /mnt/var/lib/secure-boot-auto-enroll
        echo "secure-boot-enroll" > /mnt/var/lib/secure-boot-auto-enroll/state
        echo "Secure boot automation will run on first boot"
      '';
    })

    (pkgs.writeShellApplication {
      name = "full-install";
      text = ''
        disk-prepare && lanzaboote-prepare && system-install && secure-boot-kickstart && reboot
      '';
    })
  ];

  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  # Optional: faster ISO squash
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";
}
