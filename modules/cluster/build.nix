{ config, lib, pkgs, terraformModulesPath, ... }:

with lib;

{
  options.build = with types; {
    secrets = mkOption {
      readOnly = true;
      type = path;
      default = with pkgs; buildEnv {
        name = "cluster-secrets";
        paths = map
          (node:
            node.config.secrets.generator.out
          )
          (builtins.attrValues config.nodes);
      };
    };

    systems = mkOption {
      readOnly = true;
      type = path;
      default = with pkgs; linkFarm "cluster-systems"
        ((map
          (node: {
            name = node.config.networking.hostName;
            path =
              node.config.system.build.toplevel;
          }
          )
          (builtins.attrValues config.nodes)
        ) ++ [
          { name = "metadata.json"; path = config.build.metadata; }
          { name = "terraform"; path = config.build.terraformModules; }
        ]);
    };

    metadata = mkOption {
      type = path;
      default = with pkgs; writeText "cluster-metadata.json" (builtins.toJSON {
        inherit (config) pools;
      });
    };

    terraformModules = mkOption {
      default = with pkgs; runCommandNoCC "terraform-modules" { } ''
        cp -r ${terraformModulesPath} $out
        substituteInPlace \
            $out/modules/nixos-deployment/main.tf \
                --subst-var-by "nixos-deploy" "${nixos-deploy}"
      '';
    };
  };
}
