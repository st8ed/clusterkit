{ config, pkgs, lib, clusterConfig, ... }:

with lib;

let
  cfg = config.services.kubernetes.kubelet;

in
{
  options.images = with lib; with lib.types; mkOption {
    type = listOf anything;
    default = [ ];
  };

  config = mkIf cfg.enable {
    secrets.pki = with clusterConfig.lib; certsForHost config "kubernetes" (certs: {
      inherit (certs)
        kubernetes-ca
        kubernetes-kubelet
        kubernetes-proxy;
    });

    networking.firewall.allowedTCPPorts = [
      config.services.kubernetes.kubelet.port
    ];

    services.kubernetes.kubelet = mkMerge [
      ({
        hostname = config.networking.fqdn;
        seedDockerImages = mkForce [ ]; # Use custom patched seeding algorithm

        unschedulable = false;
        taints = {
          master = mkIf config.services.kubernetes.apiserver.enable {
            key = "node-role.kubernetes.io/master";
            value = "true";
            effect = "NoSchedule";
          };
        };

        extraOpts =
          let
            labels = concatMapStringsSep "," (v: "${v.name}=${v.value}") (mapAttrsToList nameValuePair {
              # TODO: Configurable node labels
            });
          in
          ''
            --node-labels=${labels} \
            --image-gc-high-threshold=100 \
            --eviction-hard=imagefs.available<5%,memory.available<100Mi,nodefs.available<5%
          ''; # TODO: Configurable gc thresholds

      })
      (with config.secrets.pki; {
        kubeconfig = {
          server = clusterConfig.apiserverAddress;
          caFile = kubernetes-ca.certFile;
          certFile = kubernetes-kubelet.certFile;
          keyFile = kubernetes-kubelet.keyFile;
        };

        clientCaFile = kubernetes-ca.certFile;
        tlsKeyFile = kubernetes-kubelet.keyFile;
        tlsCertFile = kubernetes-kubelet.certFile;
      })
    ];

    services.kubernetes.proxy = mkMerge [
      ({
        enable = true;
        hostname = config.networking.fqdn;
      })
      (with config.secrets.pki; {
        kubeconfig = {
          server = clusterConfig.apiserverAddress;
          caFile = kubernetes-ca.certFile;
          certFile = kubernetes-proxy.certFile;
          keyFile = kubernetes-proxy.keyFile;
        };
      })
    ];

    # TODO: Find a better way to seed images
    # and check digests
    systemd.services.kubelet = {
      path = with pkgs; [ cri-tools ];
      preStart = ''
        ${concatMapStrings (img: ''
          export CONTAINER_RUNTIME_ENDPOINT="unix:///run/containerd/containerd.sock"
          if ! crictl inspecti -q "${img.imageName}:${img.imageTag}" 2>&1 >/dev/null; then
            echo "Seeding container image: ${img.imageName}:${img.imageTag} from ${img}"
            ${if (lib.hasSuffix "gz" img) then
              ''${pkgs.gzip}/bin/zcat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import --all-platforms -''
            else
              ''${pkgs.coreutils}/bin/cat "${img}" | ${pkgs.containerd}/bin/ctr -n k8s.io image import --all-platforms -''
            }
          else
            echo "Container image exists: ${img.imageName}:${img.imageTag}"
          fi
        '') (clusterConfig.images pkgs)}
      '';
    };
  };
}
