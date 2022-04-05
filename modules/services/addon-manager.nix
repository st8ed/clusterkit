{ pkgs, config, clusterConfig, lib, ... }:

with lib;

let
  cfg = config.services.kubernetes.addonManager;
  inherit (config.services.kubernetes.lib) mkKubeConfig;

in
{
  config = mkIf cfg.enable {
    secrets.files = assert config.services.kubernetes.apiserver.enable; {
      "cluster-admin.kubeconfig".mount = {
        enable = true;
        path = "/etc/kubernetes/cluster-admin.kubeconfig";
      };
    };

    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs) kubernetes-ca kubernetes-addon-manager;
    });

    systemd.services.kube-addon-manager =
      {
        environment.KUBECONFIG =
          mkKubeConfig "addon-manager" {
            server = clusterConfig.apiserverAddress;
            caFile = config.secrets.pki.kubernetes-ca.certFile;
            certFile = config.secrets.pki.kubernetes-addon-manager.certFile;
            keyFile = config.secrets.pki.kubernetes-addon-manager.keyFile;
          };

        serviceConfig.PermissionsStartOnly = true;
        preStart = with pkgs;
          let
            files = mapAttrsToList (n: v: writeText "${n}.json" (builtins.toJSON v))
              config.services.kubernetes.addonManager.bootstrapAddons;
          in
          ''
            export KUBECONFIG=/etc/kubernetes/cluster-admin.kubeconfig
            ${kubectl}/bin/kubectl apply -f ${concatStringsSep " \\\n -f " files}
          '';
      };
  };
}
