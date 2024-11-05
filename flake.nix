{
  description = "Crash reproduction";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs =
    { self
    , nixpkgs
    }@inputs: {
      nixosConfigurations = {
        # Temporarily added this to test a kernel bug
        nixos-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };
      };
    };
}
