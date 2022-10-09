{ config, lib, ... }:

with lib;

let
  # FIXME: Configurable defaults for certs
  defaults = {
    csr.key.algo = "rsa";
    csr.key.size = 3072;
    expiry = "2190h";
  };

  mkCsr = name: { cn, altNames ? [ ], organization ? null }: builtins.toFile "${name}-csr.json" (builtins.toJSON (lib.attrsets.recursiveUpdate defaults.csr {
    CN = cn;
    hosts = [ cn ] ++ altNames;
    names = if organization == null then null else [
      { "O" = organization; }
    ];
  }));

  caConfig = builtins.toFile "ca-config.json" (builtins.toJSON {
    signing.profiles = {
      server = { inherit (defaults) expiry; usages = [ "signing" "key encipherment" "client auth" "server auth" ]; };
      client = { inherit (defaults) expiry; usages = [ "signing" "key encipherment" "client auth" "server auth" ]; };
      peer = { inherit (defaults) expiry; usages = [ "signing" "key encipherment" "client auth" ]; };
    };
  });

in
{
  config = {
    secrets.generators = {
      mkCa = { csr, path }: secret: ''
        if [ ! -f "${path}.gpg" ]; then
          tmpkeydir=$(mktemp -d)

          cfssl gencert -loglevel 2 -initca "${mkCsr secret.name csr}" \
            | cfssljson -bare "$tmpkeydir"/ca

          mkdir -p "${builtins.dirOf path}"
          cp "$tmpkeydir"/ca.pem "${lib.removeSuffix "-key.pem" path}.pem" 
          gpg --encrypt -r "${config.secrets.gpgUser}" \
            <"$tmpkeydir"/ca-key.pem \
            >"${path}.gpg"

          rm -rf "$tmpkeydir"
        fi

        secret_value="$(gpg --decrypt "${path}.gpg" 2>/dev/null)"
      '';

      mkCert = { csr, path, ca_path, profile }: secret: ''
        if [ ! -f "${path}.gpg" ]; then
          tmpkeydir=$(mktemp -d)

          cfssl gencert \
              -loglevel 2 \
              -ca "${lib.removeSuffix "-key.pem" ca_path}.pem" \
              -ca-key <(gpg --decrypt "${ca_path}.gpg" 2>/dev/null) \
              -config "${caConfig}" \
              -profile "${profile}" \
              "${mkCsr secret.name csr}" \
              | cfssljson -bare "$tmpkeydir"/cert
          
          mkdir -p "${builtins.dirOf path}" 
          cp "$tmpkeydir"/cert.pem "${lib.removeSuffix "-key.pem" path}.pem" 
          gpg --encrypt -r "${config.secrets.gpgUser}" \
            <"$tmpkeydir"/cert-key.pem \
            >"${path}.gpg"

          rm -rf "$tmpkeydir"
        fi

        secret_value="$(gpg --decrypt "${path}.gpg" 2>/dev/null)"
      '';
    };
  };
}
