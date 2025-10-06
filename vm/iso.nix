{ inputs }:
{ pkgs }:
let
  inherit (pkgs.hostPlatform) system;
  inherit (inputs.self.packages.${system}) installer-iso;
in
pkgs.writeShellScriptBin "iso-vm" ''
  set -euo pipefail

  STATE_DIR="''${STATE_DIR:-state}"
  # Create $STATE_DIR if it doesn't exist
  if [ ! -d "$STATE_DIR" ]; then
    echo "Creating state folder $STATE_DIR"
    mkdir $STATE_DIR
  fi

  DISK_SIZE="''${DISK_SIZE:-20G}"

  # Create disk.qcow2 if it doesn't exist
  if [ ! -f "$STATE_DIR/disk.qcow2" ]; then
    echo "Creating empty $STATE_DIR/disk.qcow2 ($DISK_SIZE) from target system config)..."
    ${pkgs.qemu}/bin/qemu-img create -f qcow2 $STATE_DIR/disk.qcow2 $DISK_SIZE
  fi

  OVMF_CODE="${pkgs.OVMFFull.fd}/FV/OVMF_CODE.ms.fd"
  OVMF_VARS="ovmf_vars.ms.fd"

  # Create OVMF vars file if it doesn't exist
  if [ ! -f "$STATE_DIR/$OVMF_VARS" ]; then
    echo "Creating OVMF variables file..."
    cp "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.ms.fd" "$STATE_DIR/$OVMF_VARS"
    chmod u+w "$STATE_DIR/$OVMF_VARS"
  fi

  # TPM setup
  if [ ! -d $STATE_DIR/tpm ]; then
    echo "Creating $STATE_DIR/TPM state directory..."
    mkdir -p $STATE_DIR/tpm
  fi

  # Installer ISO path
  INSTALLER_ISO="${installer-iso}/iso/${installer-iso.isoName}"

  if [ ! -S "$STATE_DIR/tpm/swtpm-sock" ]; then
    echo "Starting TPM emulator..."
    ${pkgs.swtpm}/bin/swtpm socket --tpm2 --tpmstate dir="$STATE_DIR/tpm" --ctrl type=unixio,path="$STATE_DIR/tpm/swtpm-sock" --daemon
    # Give swtpm time to start
    sleep 1
  else
    echo "TPM socket already exists, reusing..."
  fi

  exec ${pkgs.qemu}/bin/qemu-system-x86_64 \
    -enable-kvm \
    -m 4096 \
    -smp 4 \
    -machine q35 \
    -cpu host \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$STATE_DIR/$OVMF_VARS" \
    -device virtio-scsi-pci,id=scsi0 \
    -drive if=none,id=hd0,file="$STATE_DIR/disk.qcow2",format=qcow2 \
    -device virtio-blk,drive=hd0 \
    -drive if=none,id=cd0,file="$INSTALLER_ISO",format=raw,readonly=on,media=cdrom \
    -device scsi-cd,drive=cd0,bus=scsi0.0 \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -serial mon:stdio \
    -boot menu=on,splash-time=1000 \
    -chardev socket,id=chrtpm,path=$STATE_DIR/tpm/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
    -vga virtio -display gtk
''
