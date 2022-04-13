{ pkgs, lib, nixos-switch, openssh, sops }:
pkgs.writeShellApplication {
  name = "nixos-deploy";
  runtimeInputs = [ openssh sops ];
  text =
    ''
      target="root@$1"
      path="$(readlink -f "$2")"
      secrets="$(readlink -f "$3")"
      export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new"

      function cmd() {
        ssh -o StrictHostKeyChecking=accept-new "$@"
      }

      if [ -n "$secrets" ]; then
        key="$(sops -d --extract '["host-key"]' "$secrets")"
        # TODO: Should we copy gpg closure too?
        echo -n "$key" | cmd "$target" gpg --import -
      fi

      # TODO: Copy system-specfic version of nixos-switch
      nix copy --substitute-on-destination --to "ssh://$target" "$path" "${nixos-switch}"
          
      # shellcheck disable=SC2029
      cmd "$target" \
        "${lib.getBin nixos-switch}/bin/${nixos-switch.meta.mainProgram}" \
        "$path"
    '';
}
