{ pkgs, config, lib, clusterConfig, ... }:

with lib;

let
  cfg = clusterConfig.addons.flannel;

in
{
  config = mkIf cfg.enable {
    services.kubernetes.addonManager.bootstrapAddons = {
      flannel-cr = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = { name = "flannel"; };
        rules = [{
          apiGroups = [ "" ];
          resources = [ "pods" ];
          verbs = [ "get" ];
        }
          {
            apiGroups = [ "" ];
            resources = [ "nodes" ];
            verbs = [ "list" "watch" ];
          }
          {
            apiGroups = [ "" ];
            resources = [ "nodes/status" ];
            verbs = [ "patch" ];
          }];
      };

      flannel-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = { name = "flannel"; };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "flannel";
        };
        subjects = [{
          kind = "User";
          name = "flannel-client";
        }];
      };
    };

    services.kubernetes.addonManager.addons = { };
  };
}
        
