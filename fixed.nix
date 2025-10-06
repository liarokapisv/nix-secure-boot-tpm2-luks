{
  inputs,
}:
{
  imports = [
    (import ./hardware.nix { inherit inputs; })
  ];

  # should always be on otherwise we lose have access.
  services = {
    netbird.enable = true;
    openssh.enable = true;
  };
}
