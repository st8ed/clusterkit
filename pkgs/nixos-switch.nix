{ pkgs }:
pkgs.writeShellApplication {
  name = "nixos-switch";
  text = ''
    path=$1
    profile=/nix/var/nix/profiles/system
    # generations="+10"

    current="$(readlink /run/current-system)"
    if [ "$current" = "$path" ]; then
      echo "System is up to date"
      exit 0
    fi

    nix-env -p "$profile" --set "$path"

    kernel_old="$(readlink /run/current-system/kernel)"
    kernel_new="$(readlink "$path/kernel")"

    if [ "$kernel_old" != "$kernel_new" ]; then
      export NIXOS_INSTALL_BOOTLOADER=1
      "$path"/bin/switch-to-configuration boot
      echo "System is going to reboot after kernel update"
      exec reboot
    fi

    hostname_old="$(hostname)"

    "$path"/bin/switch-to-configuration switch
    # nix-env -p "$profile" --delete-generations "$generations"
    # nix-store --gc

    hostname_new="$(hostname)"

    if [ "$hostname_old" != "$hostname_new" ]; then
      systemctl restart dhcpcd
    fi
  '';
}
