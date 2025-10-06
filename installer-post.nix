{
  inputs,
  target,
}:
{
  pkgs,
  lib,
  ...
}:
let
  targetSystem = target.config.system.build.toplevel;
  targetHostName = target.config.networking.hostName;
  closureInfo = pkgs.closureInfo {
    rootPaths = [
      targetSystem
    ];
  };

in
{
  imports = [
    (import ./hardware.nix { inherit inputs; })
  ];

  networking.hostName = "installer-post";
  services.netbird.enable = true;
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    sbctl
    tpm2-tools
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.register-to-netbird
  ];

  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  environment.loginShellInit = ''
    STATE_DIR="/var/lib/secure-boot-auto-enroll"
    STATE_FLAG="$STATE_DIR/state"
    LUKS_DEVICE="/dev/disk/by-partlabel/disk-main-root"

    if [ ! -f "$STATE_FLAG" ]; then
      echo "No state flag found - automation inactive"
      eval bash
    fi

    STATE=$(cat "$STATE_FLAG")

    case "$STATE" in
      "secure-boot-enroll")
        echo "Checking secure boot setup mode..."
        
        if ! sbctl status | grep -q "Setup Mode.*Enabled"; then
          echo "WARNING: Secure boot is not in setup mode. Manual intervention may be needed."
          logger "secure-boot-auto-enroll: Setup mode not detected"
          exit 1
        fi
        
        echo "Setup mode detected, enrolling keys..."
        sbctl enroll-keys --microsoft

        echo "tpm2-enroll" > "$STATE_FLAG"
        echo "Keys enrolled, rebooting for PCR7 update..."
        reboot
        ;;
        
      "tpm2-enroll")
        echo "Checking secure boot status for TPM2 enrollment..."
        
        if ! sbctl status | grep -q "Secure Boot.*Enabled"; then
          echo "WARNING: Secure boot is not enabled. Cannot proceed with TPM2 enrollment."
          logger "secure-boot-auto-enroll: Secure boot not enabled"
          exit 1
        fi
        
        echo "Secure boot active, enrolling TPM2..."
        systemd-cryptenroll --tpm2-device=auto \
          --tpm2-pcrs=7+15:sha256=0000000000000000000000000000000000000000000000000000000000000000 \
          --wipe-slot=tpm2,empty \
          --unlock-key-file=/dev/null \
          "$LUKS_DEVICE"

        echo "TPM2 enrollment completed successfully"

        rm -f "$STATE_FLAG"

        echo "Registering device to netbird network..."
        NB_HOSTNAME=${targetHostName} register_to_netbird
        echo "Registering complete! Rebooting to deploy image.."

        nix-env -p /nix/var/nix/profiles/system --set ${targetSystem}
        ${targetSystem}/bin/switch-to-configuration switch 
        nix-env --delete-generations old
        nix-collect-garbage -d
        /run/current-system/bin/switch-to-configuration boot
        reboot
        ;;
        
      *)
        echo "Unknown state: $STATE"
        exit 1
        ;;
    esac
  '';

  system.stateVersion = "25.11";
}
