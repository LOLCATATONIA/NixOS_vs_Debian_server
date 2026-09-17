{ config, pkgs, ... }:
{
  imports = [
    ./modules/network.nix
    ./modules/users.nix
    ./modules/filesystem.nix
    ./modules/firewall.nix
    ./modules/monitoring.nix
  ];

  system.stateVersion = "24.05";

  environment.systemPackages = with pkgs; [
    vim
    git
    acl
    tealdeer
  ];
}
