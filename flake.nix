{
  description = "Linux 101 - hardened NixOS server (VM)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }: {
    nixosConfigurations.linux101-srv = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./nixos/configuration.nix ./nixos/hardware-vm.nix ];
    };

    packages.x86_64-linux.qcow = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [ ./nixos/configuration.nix ];
      format = "qcow";
    };
  };
}
