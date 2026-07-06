{ config, pkgs, vars, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
    # enableNvidia = true;
  };

  environment.systemPackages = with pkgs; [
    lazydocker
    docker-compose
  ];

  users.groups.docker.members = [ vars.username ];

  # Allow containers on Docker bridge networks to reach host services
  # (e.g. an Obsidian Local REST API plugin listening on the host).
  # Default Docker bridge is docker0; docker-compose user networks get
  # br-<hash> interfaces. We accept by interface name AND by source IP
  # range as a fallback. Uses iptables syntax so it works under both
  # nftables and iptables-legacy firewall backends.
  networking.firewall.trustedInterfaces = [ "docker0" ];
  networking.firewall.extraCommands = ''
    iptables -I INPUT -s 172.16.0.0/12 -j ACCEPT \
      -m comment --comment "docker bridge IP range"
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep '^br-'); do
      iptables -I INPUT -i "$iface" -j ACCEPT \
        -m comment --comment "docker-compose user bridge"
    done
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D INPUT -s 172.16.0.0/12 -j ACCEPT \
      -m comment --comment "docker bridge IP range" 2>/dev/null || true
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep '^br-'); do
      iptables -D INPUT -i "$iface" -j ACCEPT \
        -m comment --comment "docker-compose user bridge" 2>/dev/null || true
    done
  '';
}
