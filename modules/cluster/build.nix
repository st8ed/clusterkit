{ config, lib, hostPkgs, terraformModulesPath, ... }:

with lib;

{
  options.build = with types; {
    secrets = mkOption {
      readOnly = true;
      type = path;
      default = with hostPkgs; buildEnv {
        name = "cluster-secrets";
        paths = map
          (node:
            (node.config.secrets.generator hostPkgs).out
          )
          (builtins.attrValues config.nodes);
      };
    };

    systems = mkOption {
      readOnly = true;
      type = path;
      default = with hostPkgs; linkFarm "cluster-systems"
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
      default = with hostPkgs; writeText "cluster-metadata.json" (builtins.toJSON {
        inherit (config) pools;
      });
    };

    terraformModules = mkOption {
      default = terraformModulesPath;
    };
  };
}
