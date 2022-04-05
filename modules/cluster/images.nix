{ config, pkgs, lib, ... }:

with lib;

{
  options.images = with types; mkOption {
    type = anything;
  };

  config.images = pkgs: with pkgs; [
    (dockerTools.buildImage {
      name = "pause"; # TODO: override --pod-infra-container-image=
      tag = "latest";

      contents = kubernetes.pause;
      config.Cmd = [ "/bin/pause" ];
    })

    (dockerTools.buildImage {
      name = "${config.domain}/coredns";
      tag = "latest";

      contents = [ coredns iana-etc cacert ];
      config.Entrypoint = [ "/bin/coredns" ];
      config.Cmd = [ "-c" "/etc/coredns/Corefile" ];
    })

    (dockerTools.buildImage {
      name = "${config.domain}/toolbox";
      tag = "latest";

      contents = [ bashInteractive iana-etc cacert ];
      config.Cmd = [ "/bin/bash" ];
      config.Env = [
        "PATH=${makeBinPath [
                    coreutils
                    util-linux
                    iputils
                    iproute2
                    iptables
                    curl
                    wget
                    vim
                    socat
                    tcpdump
                    dnsutils
                    dig
                    psmisc
                    git
                    htop
                    nmap
                ]}"
      ];
    })
  ];
}


