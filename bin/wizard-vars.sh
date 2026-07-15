#!/usr/bin/env bash
set -euo pipefail

SOURCE="${NIXOS_CONFIG_SOURCE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET="${NIXOS_CONFIG_TARGET:-/etc/nixos}"
EXAMPLE="$SOURCE/vars.nix.example"
OUTPUT="${1:-$TARGET/vars.nix}"

prompt() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local value
  read -r -p "$prompt_text [$default_value]: " value
  echo "${value:-$default_value}"
}

prompt_bool() {
  local prompt_text="$1"
  local default_value="$2"
  local value
  read -r -p "$prompt_text [y/N]: " value
  if [[ "$default_value" == "true" && -z "$value" ]] || [[ "$value" =~ ^[Yy]$ ]]; then
    echo "true"
  else
    echo "false"
  fi
}

hash_password() {
  local password="$1"
  if command -v mkpasswd >/dev/null 2>&1; then
    mkpasswd -m sha-512 "$password"
    return 0
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl passwd -6 "$password"
    return 0
  fi
  if command -v nix >/dev/null 2>&1; then
    nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512 "$password" 2>/dev/null && return 0
  fi
  return 1
}

prompt_password_hash() {
  local pass pass2 hash
  read -r -s -p "Пароль пользователя (Enter = задать позже через passwd): " pass
  echo
  if [[ -z "$pass" ]]; then
    echo "null"
    return 0
  fi
  read -r -s -p "Повторите пароль: " pass2
  echo
  if [[ "$pass" != "$pass2" ]]; then
    echo "Ошибка: пароли не совпадают" >&2
    exit 1
  fi
  if ! hash="$(hash_password "$pass")"; then
    echo "Не найден mkpasswd/openssl/nix. hashedPassword = null." >&2
    echo "После первого входа: sudo passwd $username" >&2
    echo "null"
    return 0
  fi
  echo "\"$hash\""
}

if [[ ! -f "$EXAMPLE" ]]; then
  echo "Ошибка: vars.nix.example не найден: $EXAMPLE" >&2
  exit 1
fi

username=$(prompt username "Имя пользователя" "user")
homeDirectory="/home/$username"
hostname=$(prompt hostname "Hostname" "nixos")
timezone=$(prompt timezone "Timezone" "Europe/Moscow")
locale=$(prompt locale "Locale" "ru_RU.UTF-8")
theme=$(prompt theme "Тема (catppuccin/crimson/catppuccin-mocha)" "catppuccin")
browser=$(prompt browser "Браузер (floorp/librewolf)" "floorp")
terminal=$(prompt terminal "Терминал (kitty)" "kitty")
monitor=$(prompt monitor "Монитор Hyprland" ",preferred,auto,1")
gitUsername=$(prompt gitUsername "Git имя" "Your Name")
gitEmail=$(prompt gitEmail "Git email" "you@example.com")
hashedPassword=$(prompt_password_hash)

lat=$(prompt lat "Широта для redshift" "55.75")
lon=$(prompt lon "Долгота для redshift" "37.62")

docker=$(prompt_bool "Docker?" false)
k8s=$(prompt_bool "Kubernetes tools?" false)
gaming=$(prompt_bool "Gaming (Steam, Wine)?" false)
nvidia=$(prompt_bool "NVIDIA drivers?" false)
vpn=$(prompt_bool "VPN (OpenVPN, WireGuard)?" false)
flatpak=$(prompt_bool "Flatpak?" true)
devTools=$(prompt_bool "Dev tools?" true)
openWebui=$(prompt_bool "Open WebUI?" false)
maxSandbox=$(prompt_bool "MAX sandbox VM?" false)
deepcool=$(prompt_bool "DeepCool LCD?" false)

ags=$(prompt_bool "AGS widgets?" true)
spotify=$(prompt_bool "Spotify?" true)
telegram=$(prompt_bool "Telegram (AyuGram)?" true)
discord=$(prompt_bool "Discord?" true)
planify=$(prompt_bool "Planify?" true)
cursor=$(prompt_bool "Cursor editor?" true)
vscode=$(prompt_bool "VS Code?" true)
zed=$(prompt_bool "Zed editor?" false)
lunarvim=$(prompt_bool "LunarVim?" false)

cat > "$OUTPUT" <<EOF
{
  features = {
    docker = $docker;
    k8s = $k8s;
    gaming = $gaming;
    nvidia = $nvidia;
    vpn = $vpn;
    deepcool = $deepcool;
    maxSandbox = $maxSandbox;
    maxBypassVpn = false;
    openWebui = $openWebui;
    devTools = $devTools;
    flatpak = $flatpak;
    sshPasswordAuth = false;
  };

  programs = {
    ags = $ags;
    spotify = $spotify;
    telegram = $telegram;
    discord = $discord;
    planify = $planify;
    cursor = $cursor;
    vscode = $vscode;
    zed = $zed;
    lunarvim = $lunarvim;
    steam = false;
  };

  theme = "$theme";
  username = "$username";
  homeDirectory = "$homeDirectory";
  gitUsername = "$gitUsername";
  gitEmail = "$gitEmail";
  hostname = "$hostname";
  timezone = "$timezone";
  locale = "$locale";
  supportedLocales = [ "ru_RU.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
  hashedPassword = $hashedPassword;
  monitor = "$monitor";
  additionalMonitors = [ ];
  workspaceMonitorBindings = [ ];
  terminal = "$terminal";
  browser = "$browser";
  kbLayouts = "us, ru";
  kbOptions = "grp:win_space_toggle";
  animatedWallpapersDir = "Pictures/animated";
  staticWallpapersDir = "Pictures/static";
  defaultWallpaper = "default.jpg";
  stateVersion = "25.05";
  agsPopupTimeout = 3;
  deepcoolScript = null;
  location = { latitude = $lat; longitude = $lon; };
  vpn = {
    openvpnConfigs = [ ];
    wireguardConfigs = [ ];
  };
  gamemodeGpuDevice = 0;
}
EOF

echo "Создан: $OUTPUT"
