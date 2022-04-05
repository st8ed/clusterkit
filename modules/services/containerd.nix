{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.virtualisation.containerd;

in
{
  config = mkIf cfg.enable {
    virtualisation.containerd = { };

    environment.systemPackages = with pkgs; [
      cri-tools
      # cnitool
    ];

    environment.variables = {
      CONTAINER_RUNTIME_ENDPOINT = "unix:///run/containerd/containerd.sock";
    };
  };
}
