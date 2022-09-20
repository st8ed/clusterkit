{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, sops-nix } @ inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      buildSystem = "x86_64-linux";

      lib = nixpkgs.lib.extend (self: super: {
        nixosSystem = args: super.nixosSystem (args //
          {
            modules = args.modules ++ [
              { nixpkgs.overlays = [ inputs.self.overlay ]; }
              inputs.self.nixosModule
            ];
          }
        );
      });

      nixpkgsFor = lib.genAttrs supportedSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });

      forAllSystems = lib.genAttrs supportedSystems;

      mkCluster = self: module: lib.evalModules {
        modules = [
          {
            _module.args = {
              pkgs = nixpkgsFor."${buildSystem}";
              hostPkgs = nixpkgsFor."${buildSystem}";
              terraformModulesPath = ./resources;
              inputs = {
                inherit self;
              };
            };
          }
          ./modules/cluster
          module
        ];
      };
    in
    {
      inherit lib nixpkgsFor mkCluster;

      overlay = self: super: {
        cluster-build = self.callPackage ./pkgs/cluster-build.nix { };
        cluster-update = self.callPackage ./pkgs/cluster-update.nix { };
        nixos-switch = self.callPackage ./pkgs/nixos-switch.nix { };
        nixos-deploy = self.callPackage ./pkgs/nixos-deploy.nix { };
      };

      nixosModule.imports = [
        sops-nix.nixosModules.sops
        ({ pkgs, ... }: { environment.systemPackages = with pkgs; [ gnupg nixos-switch ]; })
      ];

      apps = forAllSystems (system: {
        inherit (nixpkgsFor."${system}") cluster-build cluster-update nixos-switch nixos-deploy;
      });

      clusters = rec { };
    };
}
