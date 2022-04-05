{ config, pkgs, lib, ... }:

with lib;

{
  options = with types; {
    secretsBuildDirectory = mkOption {
      type = path;
    };
    secretsStoreDirectory = mkOption {
      type = str;
    };

    masterKey = {
      gpg = mkOption { type = str; };
      ssh = mkOption { type = str; };
    };
  };
}
