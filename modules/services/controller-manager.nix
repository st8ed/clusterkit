{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.kubernetes.controllerManager;

in
{
  config = mkIf cfg.enable {
    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs) kubernetes-ca kubernetes-controller-manager kubernetes-service-account-signer;
    });

    services.kubernetes.controllerManager = with config.secrets.pki; {
      rootCaFile = kubernetes-ca.certFile;
      serviceAccountKeyFile = kubernetes-service-account-signer.keyFile;

      kubeconfig = {
        server = clusterConfig.apiserverAddress;
        caFile = kubernetes-ca.certFile;
        certFile = kubernetes-controller-manager.certFile;
        keyFile = kubernetes-controller-manager.keyFile;
      };
    };
  };
}
