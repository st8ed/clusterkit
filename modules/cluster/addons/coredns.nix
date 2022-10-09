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

      extraConfig = mkOption {
        type = types.str;
        default = "";
      };

      forwardConfig = mkOption {
        type = types.str;
        default = ''
          forward . tls://1.1.1.1 tls://1.0.0.1 {
              tls_servername cloudflare-dns.com
              health_check 5s
          }
        '';
      };

      corefile = mkOption {
        type = types.lines;
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
            
            ${cfg.forwardConfig}
            
            cache 30
            loop
            reload
            loadbalance
          }
          ${cfg.extraConfig}
        '';
      };
    };
  };
}
