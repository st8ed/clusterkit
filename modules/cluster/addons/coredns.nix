{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.addons.coredns;
in
{
  options = {
    addons.coredns = {
      enable = mkEnableOption "";

      reconcileMode = mkOption {
        default = "Reconcile";
        type = types.enum [ "Reconcile" "EnsureExists" ];
      };

      replicas = mkOption {
        default = 2;
        type = types.int;
      };

      image = mkOption {
        type = types.attrs;
        default = {
          imageName = "${config.domain}/coredns";
          imageTag = "latest";
        };
      };

      corefile = mkOption {
        type = types.str;
        default = ''
          .:53 {
            errors
            health {
              lameduck 5s
            }
            ready
            kubernetes ${config.domain} in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
            }
            prometheus :9153
            forward . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
          }'';
      };
    };
  };
}
