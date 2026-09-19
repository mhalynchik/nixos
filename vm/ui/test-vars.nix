{ lib }:

let
  defaults = import ../../vars.nix.example;
in
import ../../lib/merge-vars.nix defaults {
  features = lib.mapAttrs (_: _: false) defaults.features;
  programs = (lib.mapAttrs (_: _: false) defaults.programs) // { ags = true; };
  username = "ui";
  homeDirectory = "/home/ui";
  hostname = "ui-test";
  gitUsername = "UI Test";
  gitEmail = "ui@example.invalid";
  browser = "librewolf";
  monitor = ",1280x800@60,auto,1";
  kbLayouts = "us";
  defaultWallpaper = "default.png";
  agsPopupTimeout = 30;
}
