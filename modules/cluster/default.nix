{
  imports = [
    ./addons/coredns.nix
    ./addons/flannel.nix

    ./build.nix
    ./certs.nix
    ./common.nix
    ./deployments.nix
    ./images.nix
    ./secrets.nix
  ];
}
