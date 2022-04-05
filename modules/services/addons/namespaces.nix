{ pkgs, config, lib, clusterConfig, ... }:

with lib;

let
  pools = clusterConfig.pools;
  namespaces = builtins.listToAttrs (flatten (mapAttrsToList
    (pname: pool: map
      (name: {
        name = "ns-${name}";
        value = {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            inherit name;
            annotations = {
              "scheduler.alpha.kubernetes.io/node-selector" = "node-restriction.kubernetes.io/pool=${pname}";
            };
          };
        };
      })
      pool.namespaces)
    pools));

in
{
  config = {
    services.kubernetes.addonManager.bootstrapAddons = namespaces;
    services.kubernetes.addonManager.addons = { };
  };
}
