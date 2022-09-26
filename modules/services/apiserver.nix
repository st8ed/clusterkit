{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.kubernetes.apiserver;

in
{
  config = mkIf cfg.enable {


    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs)
        etcd-ca
        etcd-client
        kubernetes-ca
        kubernetes-apiserver-server
        kubernetes-apiserver-client-kubelet
        kubernetes-service-account-signer
        kubernetes-cluster-admin;
    });

    services.kubernetes.apiserver = mkMerge [
      ({
        authorizationMode = mkForce [ "RBAC" "Node" ];
        enableAdmissionPlugins = [ "NodeRestriction" "PodTolerationRestriction" "PodNodeSelector" ];

        etcd.servers = if config.services.etcd.enable then [ "https://localhost:2379" ] else
        (map
          (a:
            "https://${a}:2379"
          )
          clusterConfig.services.etcd);

      })
      (with config.secrets.pki; {
        etcd = {
          caFile = etcd-ca.certFile;
          certFile = etcd-client.certFile;
          keyFile = etcd-client.keyFile;
        };

        clientCaFile = kubernetes-ca.certFile;

        tlsKeyFile = kubernetes-apiserver-server.keyFile;
        tlsCertFile = kubernetes-apiserver-server.certFile;

        kubeletClientCaFile = kubernetes-ca.certFile;
        kubeletClientCertFile = kubernetes-apiserver-client-kubelet.certFile;
        kubeletClientKeyFile = kubernetes-apiserver-client-kubelet.keyFile;

        serviceAccountKeyFile = kubernetes-service-account-signer.certFile;
        serviceAccountSigningKeyFile = kubernetes-service-account-signer.keyFile;
      })
    ];

    environment.systemPackages = with pkgs; [ kubectl ];

    networking.firewall.allowedTCPPorts = [ 6443 ];

    secrets.files."cluster-admin.kubeconfig" = {
      needs = [ "kubernetes-cluster-admin-key.pem" ];
      generator = config.secrets.generators.mkKubeconfig {
        username = "cluster-admin";
        ca = "kubernetes-ca";
        cert = "kubernetes-cluster-admin";
        path = "cluster-admin.kubeconfig";
      };

      mount.enable = true;
      mount.path = "/etc/kubernetes/cluster-admin.kubeconfig";
      mount.user = "root";
    };

    system.activationScripts.etc = stringAfter [ "users" "groups" ]
      ''
        mkdir -p /root/.kube
        ln -sf /etc/kubernetes/cluster-admin.kubeconfig /root/.kube/config
      '';
  };
}
