{ config, lib, pkgs, terraformModulesPath, ... }:

with lib;

{
  options = with types; {
    nodes = mkOption {
      type = attrsOf (submodule ({ name, ... }: {
        options.config = mkOption {
          type =
            let
              clusterConfig = config;
            in
            lib.mkOptionType {
              name = "Cluster node NixOS config";
              merge = loc: defs: (lib.nixosSystem {
                system = pkgs.system;
                modules =
                  let
                    extraConfig = {
                      _file = "module at ${__curPos.file}:${toString __curPos.line}";
                      config = {
                        _module.args = { inherit clusterConfig; };
                        networking.hostName = name;
                      };
                    };
                  in
                  [
                    ./..
                    extraConfig
                  ] ++ (map (x: x.value) defs);
              }).config;
            };
        };
      }));
    };

    pools = mkOption {
      type = nullOr (attrsOf (submodule {
        options = {
          nodes = mkOption {
            type = listOf str;
            default = [ ];
          };
          namespaces = mkOption {
            type = listOf str;
            default = [ ];
          };
        };
      }));
      default = null;
    };

    services.etcd = mkOption {
      type = listOf str;
      default = [ ];
    };

    services.apiserver = mkOption {
      type = listOf str;
      default = [ ];
    };

    serviceCidr = mkOption {
      type = str;
      default = "10.32.0.0/24";
    };

    podCidr = mkOption {
      type = types.str;
      default = "10.244.0.0/16";
    };

    apiserverAddress = mkOption {
      type = types.str;
      internal = true;
      default = "https://${head config.services.apiserver}:6443";
    };

    apiserverServiceAddress = mkOption {
      type = str;
      default = (
        concatStringsSep "." (
          take 3 (splitString "." config.serviceCidr
          )
        )
      ) + ".1";
      readOnly = true;
    };

    domain = mkOption {
      default = "cluster.internal";
      type = str;
    };

    dnsServiceAddress = mkOption {
      type = str;
      default = (
        concatStringsSep "." (
          take 3 (splitString "." config.serviceCidr
          )
        )
      ) + ".254";
    };
  };
}
