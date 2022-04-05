{ pkgs, config, lib, ... }:

with lib;

{
  options = {
    addons.flannel = {
      enable = mkEnableOption "";
    };
  };
}
