# Ikke et af opgavens 6 moduler — ren infrastruktur/plumbing.
#
# nixos-generators' "qcow"-format (formats/qcow.nix) tilføjer automatisk denne slags
# indstillinger (fileSystems, bootloader, virtio-drivere), når diskimaget bygges via
# `nix build .#qcow`, men KUN for det specifikke build-mål — ikke for den almindelige
# `nixosConfigurations`, som bruges til `nixos-rebuild switch --target-host` mod den
# kørende VM. Uden denne fil ved evalueringen ikke, at systemet har en rodfil-system
# eller en bootloader, og fejler. Værdierne herunder er kopieret fra nixos-generators'
# eget formats/qcow.nix for at beskrive den faktiske disk, som allerede kører — filen
# importeres derfor kun i nixosConfigurations.linux101-srv (se flake.nix), ikke i den
# delte nixos/configuration.nix, for at undgå dobbelt-definition ift. selve
# image-bygningen.
{ lib, modulesPath, ... }:
{
  imports = [ "${toString modulesPath}/profiles/qemu-guest.nix" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  boot.growPartition = true;
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.device = lib.mkDefault "/dev/vda";
  boot.loader.timeout = 0;
}
