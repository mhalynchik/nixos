{ config, lib, pkgs, pkgs-unstable, vars, ... }:

{
  imports =
    (import ./lib/mkEnabledModules.nix { inherit vars lib; })
    ++ [
      ./hardware-configuration.nix
    ];
}
