{ config, lib, pkgs, pkgs-unstable, vars, configDir, ... }:

{
  imports =
    (import ./lib/mkEnabledModules.nix { inherit vars lib; })
    ++ [
      "${configDir}/hardware-configuration.nix"
    ];
}
