{ config, lib, pkgs, ... }:

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
            (node.config.secrets.generator pkgs).out
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
          (with builtins; filter
            (node:
              !config.deployments.nodes."${node.config.networking.hostName}".build.remote
            )
            (attrValues config.nodes))
        ) ++ [
          { name = "metadata.json"; path = config.build.metadata; }
        ]);
    };

    metadata = mkOption {
      type = path;
      default = with pkgs; writeText "cluster-metadata.json" (builtins.toJSON {
        inherit (config) pools;
      });
    };
  };
}
