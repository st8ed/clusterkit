{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.secrets;

  pkiModule = with types; { name, config, ... }: {
    options = {
      path = mkOption {
        description = "Relative path to directory which holds secret data";
        type = str;
      };

      mount.public = mkOption {
        type = bool;
        default = config.mount.private;
      };

      mount.private = mkEnableOption "";

      mount.user = mkOption {
        type = str;
        default = "root";
      };

      ca = mkOption {
        description = "True if this cert is CA, or a path to CA as string";
        type = either bool str;
        default = false;
        # TODO: Validation logic
      };

      profile = mkOption {
        type = str;
      };

      cn = mkOption {
        type = nullOr str;
        default = null;
      };

      altNames = mkOption {
        type = listOf str;
        default = [ ];
      };

      organization = mkOption {
        type = nullOr str;
        default = null;
      };

      csr = mkOption {
        type = attrsOf anything;
        default = { inherit (config) cn altNames organization; };
        readOnly = true;
      };

      certFile = mkOption {
        type = str;
        default = "/run/secrets/${name}.pem";
        readOnly = true;
      };

      keyFile = mkOption {
        type = str;
        default = "/run/secrets/${name}-key.pem";
        readOnly = true;
      };
    };
  };

in
{
  options = with types; {
    secrets.pki = mkOption {
      type = attrsOf (submodule pkiModule);
      default = { };
    };
  };

  config = {
    secrets.files = with config.secrets.generators; mkMerge [
      (mapAttrs'
        (name: config: {
          name = "${name}-key.pem";

          value = {
            needs = mkIf (config.ca != true) [ "${config.ca}-key.pem" ];

            generator =
              let
                opts.path = "${config.path}-key.pem";
                opts.csr = config.csr;
              in
              if config.ca == true
              then mkCa opts
              else
                mkCert (opts // {
                  ca_path = cfg.pki."${config.ca}".path + "-key.pem";
                  profile = config.profile;
                });

            mount.enable = config.mount.private;
            mount.user = config.mount.user;
            mount.mode = "0400";
          };
        })
        cfg.pki)
      (mapAttrs'
        (name: config: {
          name = "${name}.pem";

          value = {
            needs = [ "${name}-key" ];
            generator = readSecretFile "${config.path}.pem";

            mount.enable = config.mount.public;
            mount.user = config.mount.user;
            mount.mode = "0444";
          };
        })
        cfg.pki)
    ];
  };
}
