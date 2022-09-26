{ config, pkgs, lib, ... }:

with lib;

{
  config = {
    secrets.generators = {
      mkKubeconfig = { username, ca, cert, path }: secret: ''
        if [ ! -f "${path}.gpg" ]; then
          tmpfile=$(mktemp)
          ${pkgs.kubectl}/bin/kubectl --kubeconfig "$tmpfile" config set-credentials "${username}" \
              --embed-certs=true \
              --client-certificate="${config.secrets.pki."${cert}".path}.pem" \
              --client-key=<(gpg --decrypt "${config.secrets.pki."${cert}".path}-key.pem.gpg")
          ${pkgs.kubectl}/bin/kubectl --kubeconfig "$tmpfile" config set-cluster localhost \
              --embed-certs=true \
              --certificate-authority=${config.secrets.pki."${ca}".path}.pem \
              --server=https://${config.networking.fqdn}:6443
          ${pkgs.kubectl}/bin/kubectl --kubeconfig "$tmpfile" config set-context default \
              --user "${username}" \
              --cluster localhost
          ${pkgs.kubectl}/bin/kubectl --kubeconfig "$tmpfile" config use-context default
          
          mkdir -p "${builtins.dirOf path}"
          gpg --encrypt -r "${config.secrets.gpgUser}" \
            <"$tmpfile" \
            >"${path}.gpg"
          
          rm -f "$tmpfile"
        fi

        secret_value="$(gpg --decrypt "${path}.gpg")"
      '';
    };
  };
}
