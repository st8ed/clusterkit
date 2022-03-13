{ config, pkgs, lib, ... }:

with lib;

let
  # FIXME: Configurable defaults for certs
  defaults = {
    csr.key.algo = "rsa";
    csr.key.size = 3072;
    expiry = "2190h";
  };

  mkCsr = name: { cn, altNames ? [ ], organization ? null }: with pkgs; writeText "${name}-csr.json" (builtins.toJSON (lib.attrsets.recursiveUpdate defaults.csr {
    CN = cn;
    hosts = [ cn ] ++ altNames;
    names = if organization == null then null else [
      { "O" = organization; }
    ];
  }));

  caConfig = pkgs.writeText "ca-config.json" (builtins.toJSON {
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
        if [ ! -f "${path}" ]; then
          mkdir -p "${builtins.dirOf path}" 
          pushd "${builtins.dirOf path}" >/dev/null

          cfssl gencert -loglevel 2 -initca "${mkCsr secret.name csr}" \
            | cfssljson -bare "${lib.removeSuffix "-key.pem" (builtins.baseNameOf path)}"

          popd
        fi

        secret_value="$(cat "${path}")"
      '';

      mkCert = { csr, path, ca_path, profile }: secret: ''
        if [ ! -f "${path}" ]; then
          mkdir -p "${builtins.dirOf path}" 

          cfssl gencert \
              -loglevel 2 \
              -ca "${lib.removeSuffix "-key.pem" ca_path}.pem" \
              -ca-key "${ca_path}" \
              -config "${caConfig}" \
              -profile "${profile}" \
              "${mkCsr secret.name csr}" \
              | cfssljson -bare "${lib.removeSuffix "-key.pem" path}"
        fi

        secret_value="$(cat "${path}")"
      '';
    };
  };
}
