{ config, pkgs, lib, inputs, ... }:

with lib;

let
  clusterConfig = config;

  script = cfg: ''
    set -x

    target=root@"$1"

    # TODO: Optimise for a single nix eval call
    # shellcheck disable=SC2034
    system_drv=$(nix eval --raw "${cfg.flakeUri}.config.system.build.toplevel.drvPath")
    system_path=$(nix eval --raw "${cfg.flakeUri}.config.system.build.toplevel.outPath")
    secrets_path=$(nix eval --raw "${cfg.flakeUri}.config.sops.defaultSopsFile")

    echo "Deploying $system_path on $target"

    export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new"

    function targetHostCmd() {
      # shellcheck disable=SC2086
      ssh -t $NIX_SSHOPTS "$target" -- "$@"
    }

    function importHostKey() {
      sops -d --extract '["host-key"]' "$secrets_path" \
        | targetHostCmd gpg --import -
    }

    function buildSystem() {
        nix copy \
          --to "ssh://$target" \
          ${if cfg.build.remote
            then ''--derivation''
            else ''--substitute-on-destination''
          } \
          "$system_path"

        ${if cfg.build.remote then ''
        targetHostCmd nix build --verbose \
          ${cfg.build.options} \
          "$system_drv"
        '' else ""}
    }

    function switchSystem() {
      targetHostCmd "$system_path/sw/bin/nixos-switch" "$system_path"
    }

    importHostKey
    buildSystem
    switchSystem
  '';

  nixos-terraform-deployment = pkgs.writeTextDir "nixos-terraform-deployment.tf" ''
    variable "target_host" {
      type = string
    }

    variable "system_uri" {
      type = string
    }

    variable "script_path" {
      type = string
    }

    data "external" "probe" {
      program = ["sh", "-c", <<EOT
        echo '{"path": "'$(nix eval --raw "''${var.system_uri}.outPath")'"}'
    EOT
      ]
    }

    resource "null_resource" "system" {
      triggers = {
        system_path = data.external.probe.result.path
      }

      provisioner "local-exec" {
        command = "''${var.script_path} ''${var.target_host}"
      }
    }
  '';

  terraformPackage =
    let
      bundle = pkgs.symlinkJoin {
        name = "terraform-resources";
      };
    in
    pkgs.writeText "cluster.tf" ''
      ${concatStringsSep "\n" (mapAttrsToList
        (n: v: v.resources)
        clusterConfig.deployments.nodes
      )}
      ${clusterConfig.deployments.extraResources}
    '';

in
{
  options.rootFlake = with types; mkOption {
    type = path;
    default = ./.;
  };

  options.deployments = with types; {
    resourceManager = mkOption {
      type = enumOf [ "terraform" ];
      default = "terraform";
    };

    resourcePackage = mkOption {
      type = package;
      readOnly = true;
      default = terraformPackage;
    };

    extraResources = mkOption {
      type = lines;
      default = "";
    };

    nodes = mkOption {
      type = attrsOf (submodule ({ name, config, ... }: {
        options = {
          targetHost = mkOption {
            type = str;
            default = clusterConfig.nodes."${name}".config.networking.fqdn;
          };

          system = mkOption {
            type = package;
            default = clusterConfig.nodes."${name}".config.system.build.toplevel;
          };

          flakeUri = mkOption {
            type = package;
            default = "${inputs.self}#cluster.config.nodes.${name}";
          };

          build = {
            remote = mkEnableOption "";
            options = mkOption {
              type = separatedString " ";
              default = "";
            };
          };

          script = mkOption {
            type = package;
            readOnly = true;
            default = pkgs.writeShellApplication {
              name = "cluster-deploy-${name}";
              text = script config;
            };
          };

          resources = mkOption {
            type = str;
            readOnly = true;
            default = ''
              module "nixos-node-${name}" {
                source = "${nixos-terraform-deployment}"

                target_host = "${config.targetHost}"
                system_uri = "${config.flakeUri}.config.system.build.toplevel"
                script_path = "${config.script}/bin/cluster-deploy-${name}"
              }
            '';
          };
        };
      }));
    };
  };

  config = {
    deployments.nodes = builtins.mapAttrs (n: v: { }) clusterConfig.nodes;
  };
}
