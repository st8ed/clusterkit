{ config, clusterConfig, pkgs, lib, ... }:

with lib;

let
  cfg = config.networking.remoteNetwork;
  inherit (cfg) local;

  ports.ike = 500;
  ports.nat_t = 4500;

in
{
  options.networking.remoteNetwork = with types; {
    enable = mkEnableOption "";
    local = mkOption { type = anything; };
    connections = mkOption { type = anything; };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = builtins.attrValues ports;

    secrets.pki = with clusterConfig.lib; certsForHost config "root" (certs: recursiveUpdate
      {
        inherit (certs)
          strongSwan-ca
          strongSwan-site;
      }
      {
        strongSwan-site.cn = cfg.local.id;
      });

    secrets.files = {
      "strongSwan-ca.pem".mount.path = "/etc/swanctl/x509ca/ca.pem";
      "strongSwan-site.pem".mount.path = "/etc/swanctl/x509/siteCert.pem";
      "strongSwan-site-key.pem".mount.path = "/etc/swanctl/private/siteKey.pem";
    };

    services.strongswan-swanctl = {
      enable = true;
      strongswan.extraConfig = ''
        charon {
          port = ${toString local.ports.ike}
          port_nat_t = ${toString local.ports.nat_t}
        }
      '';
      swanctl = {
        authorities.ca.cacert = "ca.pem";
        connections = lib.mapAttrs (name: remote: {
          version = 2;
          proposals = [ "aes256-sha384-x25519" ];
          mobike = true;

          # local_addrs = [ local.addr ]; # use interface address
          local_port = ports.ike;
          local.main = {
            auth = "pubkey";
            id = "CN=${local.id}";
          };

          remote_addrs = [ remote.addr ];
          remote_port = ports.ike;
          remote.main = {
            auth = "pubkey";
            id = "CN=${remote.id}";
          };

          children = {
            "${name}" = {
              esp_proposals = [ "aes256gcm16-x25519" ];

              local_ts = local.ts;
              remote_ts = remote.ts;

              # updown = "${pkgs.strongswan}/libexec/ipsec/_updown iptables";
              start_action = "trap";
            };
          };
        }) cfg.connections;
      };
    };

    environment.systemPackages = with pkgs; [
      strongswan
    ];
  };
}
