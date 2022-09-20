{ config, lib, ... }:

# TODO: Reload services after secret has changed

with lib;

let
  cfg = config.secrets;

  generators = {
    readSecretFile = path: secret: ''secret_value="$(cat ${escapeShellArg path})"'';
    mkGPGKey = { uid, useForSecrets ? true, extraSecretKeys ? [ ] }: secret: ''
      mkdir -p gpghome
      chmod -R 700 gpghome
      if ! gpg --homedir ./gpghome --list-keys ${uid}; then
          gpg --homedir ./gpghome --batch --gen-key <<EOF
      %no-protection
      Key-Type: RSA 
      Subkey-Type: default
      Name-Email: ${uid}
      Expire-Date: 0
      EOF
      fi

      ${optionalString useForSecrets ''
      SOPS_PGP_FP='${concatStringsSep "," extraSecretKeys}'
      SOPS_PGP_FP+=",$(gpg --homedir ./gpghome --fingerprint "${uid}" | sed -n '/^\s/s/\s*//p' | tr -d ' ')"
      export SOPS_PGP_FP
      export GNUPGHOME="$(realpath ./gpghome)"
      ''}

      secret_value="$(gpg --homedir ./gpghome --export-secret-key --armor ${uid})"
    '';
  };

  buildScript = pkgs: pkgs.writeScriptBin "build-secrets-${config.networking.hostName}" (
    let
      files = (
        toposort
          (a: b: builtins.elem a.name b.value.needs)
          (mapAttrsToList nameValuePair cfg.files)
      ).result;
    in
    ''
      set -o errexit
      set -o nounset
      set -o pipefail
      export PATH="${makeBinPath (with pkgs; [ cfssl gnupg jq sops ])}:$PATH"

      out=$1

      pushd "${cfg.cacheDirectory}" 
      secrets='{}'

      ${concatStringsSep "\n" (map (v: ''
        secret_name="${v.name}"
      
        echo "> $secret_name"
        ${v.value.generator v}

        ${if v.value.mount.enable then ''
        echo "!!! > Embedding ${v.name}"
        secrets=$(
          echo -n "$secrets" | jq \
            --rawfile k <(echo -n "$secret_value") \
            ". + {\"$secret_name\": \$k}"
        )
        '' else ""}
      '') files) }

      popd

      echo -n "$secrets" \
        | sops --input-type json -e /dev/stdin > "$out" 
    ''
  );

in
{
  imports = [
    ./pki.nix
    ./pki-generator-local.nix
  ];

  options = with types; {
    secrets.sopsFile = mkOption {
      type = nullOr path;
      default = cfg.buildDirectory + "/secrets.${config.networking.hostName}.yaml";
    };

    secrets.generators = mkOption {
      type = attrsOf anything;
    };

    secrets.files = mkOption {
      type = attrsOf (submodule ({ config, ... }: {
        options = {
          needs = mkOption {
            type = listOf string;
            default = [ ];
          };

          generator = mkOption {
            type = anything;
          };

          content = mkOption {
            type = nullOr str;
            default = null;
          };

          mount = {
            enable = mkEnableOption "";

            path = mkOption {
              type = nullOr str;
              default = null;
            };

            user = mkOption {
              type = str;
              default = "root";
            };

            group = mkOption {
              type = str;
              default = "root";
            };

            mode = mkOption {
              type = str;
              default = "0400";
            };
          };
        };

        config = {
          generator = mkIf (config.content != null) (s: ''
            secret_value=${escapeShellArg config.content}
          '');
        };
      }));
      default = { };
    };

    secrets.buildDirectory = mkOption {
      type = path;
    };

    secrets.cacheDirectory = mkOption {
      type = str;
    };

    secrets.generator = mkOption {
      type = anything;
      default = buildScript;
      readOnly = true;
    };
  };

  config = mkIf (cfg.sopsFile != null) {
    secrets.generators = generators;

    sops = {
      defaultSopsFile = config.secrets.sopsFile;

      gnupg = {
        sshKeyPaths = mkForce [ ];
        home = "/root/.gnupg";
      };

      secrets = mapAttrs
        (n: v: {
          path = mkIf (v.mount.path != null) v.mount.path;
          owner = v.mount.user;
          group = v.mount.group;
          mode = v.mount.mode;
        })
        (filterAttrs
          (
            n: v: v.mount.enable
          )
          config.secrets.files);
    };
  };
}
