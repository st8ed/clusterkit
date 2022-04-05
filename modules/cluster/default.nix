{
  imports = [
    ./addons/coredns.nix
    ./addons/flannel.nix

    ./build.nix
    ./certs.nix
    ./common.nix
    ./images.nix
    ./secrets.nix
  ];
}
