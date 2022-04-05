{ config, pkgs, lib, ... }:

with lib;

let
  certs = mkMerge [
    (mkCA "etcd" {
      server = { fqdn, ... }: { cn = fqdn; altNames = [ "localhost" ]; profile = "server"; };
      peer = { fqdn, ... }: { cn = fqdn; profile = "peer"; };

      client = { hostName, ... }: { cn = hostName; profile = "client"; };
    })

    (mkCA "kubernetes" {
      apiserver-server = { fqdn, ... }: {
        cn = fqdn;
        altNames = [
          config.apiserverServiceAddress
          "kubernetes"
          "kubernetes.default"
          "kubernetes.default.svc"
          "kubernetes.default.svc.cluster"
          "kubernetes.svc.cluster.internal"
        ];
        profile = "server";
      };

      apiserver-client-kubelet = { fqdn, ... }: {
        cn = fqdn;
        organization = "system:masters";
        profile = "client";
      };

      controller-manager = { ... }: {
        cn = "system:kube-controller-manager";
        organization = "system:kube-controller-manager";
        profile = "client";
      };

      service-account-signer = { ... }: {
        cn = "system:service-account-signer";
        profile = "client";
      };

      addon-manager = { ... }: {
        cn = "system:kube-addon-manager";
        profile = "client";
      };

      proxy = { ... }: {
        cn = "system:kube-proxy";
        organization = "system:node-proxier";
        profile = "client";
      };

      scheduler = { ... }: {
        cn = "system:kube-scheduler";
        organization = "system:kube-scheduler";
        profile = "client";
      };

      cluster-admin = { ... }: {
        cn = "cluster-admin";
        organization = "system:masters";
        profile = "client";
      };

      kubelet = { hostName, fqdn, ... }: {
        cn = "system:node:${fqdn}";
        organization = "system:nodes";
        profile = "client";
        altNames = [ fqdn ];
      };

      flannel-client = { hostName, ... }: {
        cn = "flannel-client";
        profile = "client";
      };
    })
  ];

  mkCA = prefix: clients: {
    "${prefix}-ca" = config: { path = "${prefix}/ca"; ca = true; cn = "${prefix}-ca"; };
  } // (mapAttrs'
    (name: client: {
      name = "${prefix}-${name}";
      value = config:
        let c = (client { inherit (config.networking) hostName fqdn; }); in
        ({
          path = "${prefix}/${name}-${builtins.replaceStrings [":"] ["_"] c.cn}";
          ca = "${prefix}-ca";
        } // c);
    })
    clients);
in
{
  options.certs = mkOption { type = types.anything; };
  options.lib.mkCA = mkOption { type = types.anything; };
  options.lib.certsForHost = mkOption { type = types.anything; };
  config.lib.mkCA = mkCA;
  config.lib.certsForHost = nodeConfig: user: selector:
    let
      certs = mapAttrs
        (n: v:
          let
            cert = v nodeConfig;
          in
          cert // {
            mount.public = true;
            mount.private = (cert.ca != true);
            mount.user = mkIf (cert.ca != true) user;
          })
        config.certs;
    in
    selector certs;

  config.certs = certs;
}
