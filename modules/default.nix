{ config, lib, clusterConfig, ... }:

with lib;

{
  imports = [
    ./services
    ./secrets
  ];

  config = {
    services.kubernetes = {
      pki.enable = false;
      easyCerts = false;

      clusterCidr = clusterConfig.podCidr;
      apiserver.serviceClusterIpRange = clusterConfig.serviceCidr;

      kubelet.clusterDomain = clusterConfig.domain;
      kubelet.clusterDns = clusterConfig.dnsServiceAddress;
      kubelet.seedDockerImages = lib.mkForce [ ];

      addons.dns.enable = false;
      addons.dashboard.enable = false;
    };

    networking = {
      firewall.enable = true;
    };

    services.openssh = {
      passwordAuthentication = false;
      challengeResponseAuthentication = false;
    };

    users.users.root.openssh.authorizedKeys.keys = mkForce [
      config.secrets.files."ssh-master.pub".content
    ];

    secrets.buildDirectory = clusterConfig.secretsBuildDirectory;
    secrets.cacheDirectory = clusterConfig.secretsStoreDirectory;

    secrets.files = with config.secrets.generators; {
      "ssh-master.pub" = {
        mount.enable = false;
        content = clusterConfig.masterKey.ssh;
      };

      host-key = {
        generator = mkGPGKey {
          uid = "root@${config.networking.hostName}";

          useForSecrets = true;
          extraSecretKeys = [
            clusterConfig.masterKey.gpg
          ];
        };
        mount.enable = true;
      };
    };
  };
}
