{
  imports = [
    ./addons/coredns.nix
    ./addons/flannel.nix
    ./addons/namespaces.nix

    ./addon-manager.nix
    ./apiserver.nix
    ./containerd.nix
    ./controller-manager.nix
    ./etcd.nix
    ./flannel.nix
    ./kubelet.nix
    ./scheduler.nix
    ./strongswan.nix
  ];
}
