{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.etcd;

  hostName = config.networking.hostName;
  hostNameFQDN = config.networking.fqdn;

in
{
  config = mkIf cfg.enable {
    secrets.pki = with clusterConfig.lib; certsForHost config "etcd" (certs: {
      inherit (certs) etcd-ca etcd-server etcd-peer;
    });

    services.etcd = mkMerge [
      ({
        name = hostName;

        listenClientUrls = [ "https://0.0.0.0:2379" ];
        advertiseClientUrls = [ "https://${hostNameFQDN}:2379" ];

        listenPeerUrls = [ "https://0.0.0.0:2380" ];
        initialAdvertisePeerUrls = [ "https://${hostNameFQDN}:2380" ];
        initialCluster = map (r: "${builtins.head (lib.splitString "." r)}=https://${r}:2380") clusterConfig.services.etcd;
      })
      (with config.secrets.pki; {
        clientCertAuth = true;
        trustedCaFile = etcd-ca.certFile;
        certFile = etcd-server.certFile;
        keyFile = etcd-server.keyFile;

        peerClientCertAuth = true;
        peerTrustedCaFile = etcd-ca.certFile;
        peerCertFile = etcd-peer.certFile;
        peerKeyFile = etcd-peer.keyFile;
      })
    ];

    systemd.services.etcd = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };

    networking.firewall.allowedTCPPorts = [ 2379 2380 ];

    environment.variables = with config.secrets.pki; {
      ETCDCTL_API = "3";
      ETCDCTL_CACERT = etcd-ca.certFile;
      ETCDCTL_CERT = etcd-server.certFile;
      ETCDCTL_KEY = etcd-server.keyFile;
      ETCDCTL_ENDPOINTS = "https://localhost:2379";
    };
  };
}
