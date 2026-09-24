{ lib, stdenvNoCC, makeWrapper, quickshell, python3, mpv, cava,
  pulseaudio, pciutils, brightnessctl, wl-clipboard, grim, slurp, wf-recorder, xdg-user-dirs, hyprland, glib, xdg-utils, systemd, nwg-drawer, blueman, pavucontrol, networkmanagerapplet, swww, mpvpaper, ffmpeg }:
let python = python3.withPackages (ps: [ ps.pygobject3 ]); in
stdenvNoCC.mkDerivation {
  pname = "event-horizon";
  version = "0.3.0";
  src = lib.cleanSourceWith {
    src = ./ui;
    filter = path: type:
      let name = baseNameOf path;
      in name != "__pycache__" && !(lib.hasSuffix ".pyc" name);
  };
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/event-horizon" "$out/bin"
    cp -r . "$out/share/event-horizon/"
    ${python3}/bin/python3 runtime/timer_sound.py "$out/share/event-horizon/sounds"
    makeWrapper ${quickshell}/bin/qs "$out/bin/event-horizon" \
      --prefix PATH : ${lib.makeBinPath [ python mpv cava pulseaudio pciutils brightnessctl wl-clipboard grim slurp wf-recorder xdg-user-dirs hyprland glib xdg-utils systemd nwg-drawer blueman pavucontrol networkmanagerapplet swww mpvpaper ffmpeg ]} \
      --prefix GI_TYPELIB_PATH : "${glib.out}/lib/girepository-1.0" \
      --add-flags "-p $out/share/event-horizon"
    makeWrapper "$out/bin/event-horizon" "$out/bin/event-horizon-preview" \
      --set EVENT_HORIZON_PREVIEW_AUDIO 1
    makeWrapper ${python}/bin/python3 "$out/bin/event-horizon-wallpaper-restore" \
      --prefix PATH : ${lib.makeBinPath [ swww systemd ]} \
      --add-flags "$out/share/event-horizon/runtime/wallpapers.py --restore"
    runHook postInstall
  '';
  meta.description = "Cosmic desktop shell for Hyprland";
}
