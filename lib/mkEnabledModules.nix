{ vars, lib }:

[
  ../modules/system/core.nix
  ../modules/system/desktop.nix
  ../modules/system/audio.nix
  ../modules/system/bluetooth.nix
  ../modules/system/graphics.nix
  ../modules/system/packages/base.nix
  ../modules/system/ssh.nix
  ../modules/system/openrgb.nix
  ../modules/system/nix-ld.nix
  ../modules/system/redshift.nix
  ../modules/system/deepcool.nix
  ../modules/home/default.nix
  ../fonts
]
++ lib.optionals vars.features.flatpak [ ../modules/system/flatpak.nix ]
++ lib.optionals vars.features.gaming [
  ../modules/system/gaming.nix
  ../modules/system/packages/gaming.nix
]
++ lib.optionals vars.features.nvidia [ ../modules/system/nvidia.nix ]
++ lib.optionals vars.features.openWebui [ ../modules/system/open-webui.nix ]
++ lib.optionals vars.features.docker [ ../modules/services/docker.nix ]
++ lib.optionals vars.features.k8s [ ../modules/services/k8s.nix ]
++ lib.optionals vars.features.vpn [
  ../modules/services/openvpn.nix
  ../modules/services/wireguard.nix
]
++ lib.optionals vars.features.maxSandbox [ ../modules/services/virt-manager.nix ]
