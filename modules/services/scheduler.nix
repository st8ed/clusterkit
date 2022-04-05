{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.kubernetes.scheduler;

in
{
  config = mkIf cfg.enable {
    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs)
        kubernetes-ca
        kubernetes-scheduler;
    });

    services.kubernetes.scheduler = mkMerge [
      ({
        kubeconfig = {
          server = clusterConfig.apiserverAddress;
        };
      })
      (with config.secrets.pki; {
        kubeconfig = {
          caFile = kubernetes-ca.certFile;
          certFile = kubernetes-scheduler.certFile;
          keyFile = kubernetes-scheduler.keyFile;
        };
      })
    ];
  };
}
