{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.flannel;

  inherit (config.services.kubernetes.lib) mkKubeConfig;
in
{
  config = mkIf cfg.enable {
    networking = {
      dhcpcd.denyInterfaces = [ "mynet*" "flannel*" ];
      firewall.allowedUDPPorts = [
        8285 # flannel udp
        8472 # flannel vxlan
      ];
    };

    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs)
        kubernetes-ca
        kubernetes-flannel-client;
    });

    services.flannel = assert clusterConfig.addons.flannel.enable; {
      network = clusterConfig.podCidr;

      storageBackend = "kubernetes";

      nodeName = config.networking.fqdn; # TODO: FQDN
      kubeconfig = mkKubeConfig "flannel" {
        server = clusterConfig.apiserverAddress;
        caFile = config.secrets.pki.kubernetes-ca.certFile;
        certFile = config.secrets.pki.kubernetes-flannel-client.certFile;
        keyFile = config.secrets.pki.kubernetes-flannel-client.keyFile;
      };
    };

    # https://github.com/flannel-io/flannel/issues/1155
    services.resolved.enable = false;
    systemd.network = {
      enable = true;
      links."10-flannel" = {
        matchConfig.OriginalName = "flannel*";
        linkConfig.MACAddressPolicy = "none";
      };
    };

    services.kubernetes.kubelet = {
      networkPlugin = "cni";
      cni.packages = with pkgs; mkForce [ cni-plugins cni-plugin-flannel ];
      cni.config = [{
        name = "mynet";
        type = "flannel";
        cniVersion = "0.4.0";
        delegate = {
          isDefaultGateway = true;
          bridge = "mynet";
        };
      }];
    };
  };
}
