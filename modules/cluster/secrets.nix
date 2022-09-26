{ config, pkgs, lib, ... }:

with lib;

{
  options = with types; {
    secrets = mkOption {
      type = attrsOf anything;
    };

    masterKey = {
      gpg = mkOption { type = str; };
      ssh = mkOption { type = str; };
    };
  };
}
