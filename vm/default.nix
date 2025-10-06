{
  diskoLib,
  modulesPath,
  config,
  lib,
  ...
}:

let
  vm_disko = (diskoLib.testLib.prepareDiskoConfig config diskoLib.testLib.devices).disko;
  cfg_ =
    (lib.evalModules {
      modules = lib.singleton {
        # _file = toString input;
        imports = lib.singleton { disko.devices = vm_disko.devices; };
        options = {
          disko.devices = lib.mkOption {
            type = diskoLib.toplevel;
          };
          disko.testMode = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      };
    }).config;
  disks = lib.attrValues cfg_.disko.devices.disk;
  rootDisk = {
    name = "root";
    file = ''"$STATE_DIR"/${lib.escapeShellArg (builtins.head disks).imageName}.qcow2'';
    driveExtraOpts.cache = "writeback";
    driveExtraOpts.werror = "report";
    deviceExtraOpts.bootindex = "1";
    deviceExtraOpts.serial = "root";
  };
  diskoBasedConfiguration = {
    # generated from disko config
    virtualisation.fileSystems = cfg_.disko.devices._config.fileSystems;
    boot = cfg_.disko.devices._config.boot or { };
    swapDevices = cfg_.disko.devices._config.swapDevices or [ ];
  };

  hostPkgs = config.virtualisation.host.pkgs;
in
{
  imports = [
    (modulesPath + "/virtualisation/qemu-vm.nix")
    diskoBasedConfiguration
  ];

  disko.testMode = true;

  disko.imageBuilder.copyNixStore = false;
  disko.imageBuilder.extraConfig = {
    disko.devices = cfg_.disko.devices;
  };
  disko.imageBuilder.imageFormat = "qcow2";

  virtualisation.useEFIBoot = config.disko.tests.efi;
  virtualisation.memorySize = lib.mkDefault config.disko.memSize;
  virtualisation.useDefaultFilesystems = false;
  virtualisation.diskImage = null;
  virtualisation.qemu.drives = [ rootDisk ];

  system.build.vmWithDisko = hostPkgs.writers.writeDashBin "run-vm" ''
    set -efux
    export STATE_DIR="$(realpath ''${STATE_DIR:-./state})"
    if [ ! -d "$STATE_DIR" ]; then
      echo "Creating state folder $STATE_DIR"
      mkdir $STATE_DIR
    fi

    ${lib.concatMapStringsSep "\n" (disk: ''
      if [ ! -f "$STATE_DIR/${lib.escapeShellArg disk.imageName}.qcow2" ]; then
          ${hostPkgs.qemu}/bin/qemu-img create -f qcow2 \
          -b ${config.system.build.diskoImages}/${lib.escapeShellArg disk.imageName}.qcow2 \
          -F qcow2 "$STATE_DIR"/${lib.escapeShellArg disk.imageName}.qcow2
      fi
    '') disks}
    set +f
    ${config.system.build.vm}/bin/run-*-vm
  '';
}
