# VM sandbox (MAX). См. docs/max-sandbox-vm.md
{ config, lib, pkgs, vars, ... }:
{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Required for libvirt NAT network (DHCP, DNS).
  # Docker bridge rules live in services/docker.nix.
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  # MAX sandbox: block surveillance telemetry from VMs (192.168.122.0/24)
  # - ICMP: prevents GET_HOST_REACHABILITY (ping to Telegram, WhatsApp, etc.)
  # - Spy hosts: IP-detection + reachability check services from NTC research
  networking.firewall.extraCommands = let
    # IP-detection services (determine external IP → detect VPN)
    ipHosts = [
      "api.ipify.org" "checkip.amazonaws.com" "icanhazip.com" "ipinfo.io" "ifconfig.me"
      "ident.me" "ip.seeip.org" "wtfismyip.com" "myexternalip.com" "ip-api.com"
      "l2.io" "ip.sb" "api64.ipify.org"
    ];
    # Third-party reachability checks only (NOT api.oneme.ru, calls.okcdn.ru — это серверы MAX!)
    spyHosts = ipHosts ++ [
      "gosuslugi.ru" "gstatic.com"
      "main.telegram.org" "mmg.whatsapp.net" "mtalk.google.com"
    ];
    blockScript = pkgs.writeShellScript "max-sandbox-firewall" ''
      set -e
      export PATH="${pkgs.glibc.bin}/bin:${pkgs.gawk}/bin:${pkgs.coreutils}/bin:$PATH"
      # Block ICMP from VM network
      iptables -C FORWARD -s 192.168.122.0/24 -p icmp -j DROP 2>/dev/null || \
        iptables -I FORWARD -s 192.168.122.0/24 -p icmp -j DROP

      for host in ${toString spyHosts}; do
        ip=$(${pkgs.glibc.bin}/bin/getent ahostsv4 "$host" 2>/dev/null | ${pkgs.coreutils}/bin/head -1 | ${pkgs.gawk}/bin/awk '{print $1}')
        if [ -n "$ip" ]; then
          iptables -C FORWARD -s 192.168.122.0/24 -d "$ip" -j DROP 2>/dev/null || \
            iptables -I FORWARD -s 192.168.122.0/24 -d "$ip" -j DROP
        fi
      done
    '';
  in ''
    ${blockScript}
  '';

  networking.firewall.extraStopCommands = let
    spyHosts = [
      "api.ipify.org" "checkip.amazonaws.com" "icanhazip.com" "ipinfo.io" "ifconfig.me"
      "ident.me" "ip.seeip.org" "wtfismyip.com" "myexternalip.com" "ip-api.com"
      "l2.io" "ip.sb" "api64.ipify.org"
      "gosuslugi.ru" "gstatic.com"
      "main.telegram.org" "mmg.whatsapp.net" "mtalk.google.com"
    ];
    unblockScript = pkgs.writeShellScript "max-sandbox-firewall-stop" ''
      export PATH="${pkgs.glibc.bin}/bin:${pkgs.gawk}/bin:${pkgs.coreutils}/bin:$PATH"
      iptables -D FORWARD -s 192.168.122.0/24 -p icmp -j DROP 2>/dev/null || true
      for host in ${toString spyHosts}; do
        ip=$(${pkgs.glibc.bin}/bin/getent ahostsv4 "$host" 2>/dev/null | ${pkgs.coreutils}/bin/head -1 | ${pkgs.gawk}/bin/awk '{print $1}')
        if [ -n "$ip" ]; then
          iptables -D FORWARD -s 192.168.122.0/24 -d "$ip" -j DROP 2>/dev/null || true
        fi
      done
    '';
  in ''
    ${unblockScript}
  '';

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    qemu
    OVMF  # UEFI for VMs
    (writeShellScriptBin "libvirt-default-network" ''
      if ! ${libvirt}/bin/virsh net-list --all --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx default; then
        ${libvirt}/bin/virsh net-define ${writeText "libvirt-default-net.xml" ''
          <network>
            <name>default</name>
            <bridge name="virbr0"/>
            <forward mode="nat"/>
            <ip address="192.168.122.1" netmask="255.255.255.0">
              <dhcp>
                <range start="192.168.122.2" end="192.168.122.254"/>
              </dhcp>
            </ip>
          </network>
        ''}
      fi
      ${libvirt}/bin/virsh net-start default 2>/dev/null || true
      ${libvirt}/bin/virsh net-autostart default 2>/dev/null || true
      echo "Network 'default' ready. Run: virsh net-list --all"
    '')
  ];

  users.users.${vars.username}.extraGroups = [ "libvirtd" ];

  # Create default NAT network (192.168.122.0/24) if it doesn't exist
  # Uses same pattern as network-interfaces-scripted.nix for libvirtd
  system.activationScripts.libvirtDefaultNetwork = let
    netXml = pkgs.writeText "libvirt-default-net.xml" ''
      <network>
        <name>default</name>
        <bridge name="virbr0"/>
        <forward mode="nat"/>
        <ip address="192.168.122.1" netmask="255.255.255.0">
          <dhcp>
            <range start="192.168.122.2" end="192.168.122.254"/>
          </dhcp>
        </ip>
      </network>
    '';
  in ''
    if /run/current-system/systemd/bin/systemctl --quiet is-active libvirtd.service 2>/dev/null; then
      if ! ${pkgs.libvirt}/bin/virsh net-list --all --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx default; then
        ${pkgs.libvirt}/bin/virsh net-define ${netXml}
        ${pkgs.libvirt}/bin/virsh net-start default
        ${pkgs.libvirt}/bin/virsh net-autostart default
      elif ! ${pkgs.libvirt}/bin/virsh net-list --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx default; then
        ${pkgs.libvirt}/bin/virsh net-start default
        ${pkgs.libvirt}/bin/virsh net-autostart default
      fi
    fi
  '';

  # Also run at boot (activation may run before libvirtd is up)
  systemd.services.libvirt-default-network = let
    netXml = pkgs.writeText "libvirt-default-net.xml" ''
      <network>
        <name>default</name>
        <bridge name="virbr0"/>
        <forward mode="nat"/>
        <ip address="192.168.122.1" netmask="255.255.255.0">
          <dhcp>
            <range start="192.168.122.2" end="192.168.122.254"/>
          </dhcp>
        </ip>
      </network>
    '';
  in {
    description = "Create libvirt default network";
    requires = [ "libvirtd.service" ];
    after = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.libvirt pkgs.gnugrep ];
    script = ''
      for i in $(seq 1 30); do
        ${pkgs.libvirt}/bin/virsh list >/dev/null 2>&1 && break
        sleep 1
      done
      if ! ${pkgs.libvirt}/bin/virsh net-list --all --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx default; then
        ${pkgs.libvirt}/bin/virsh net-define ${netXml}
        ${pkgs.libvirt}/bin/virsh net-start default
        ${pkgs.libvirt}/bin/virsh net-autostart default
      elif ! ${pkgs.libvirt}/bin/virsh net-list --name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx default; then
        ${pkgs.libvirt}/bin/virsh net-start default
        ${pkgs.libvirt}/bin/virsh net-autostart default
      fi
    '';
  };

  # Route VM traffic (MAX) in bypass of VPN — MAX sees real IP, not VPN
  # Runs at boot; captures physical default route before VPN starts
  systemd.services.max-bypass-vpn = lib.mkIf (vars.features.maxBypassVpn or false) {
    description = "Route VM (MAX) traffic bypassing VPN";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.iproute2 pkgs.gawk ];
    script = ''
      # Remove old rule if exists
      ip rule del from 192.168.122.0/24 table 100 2>/dev/null || true
      ip route flush table 100 2>/dev/null || true
      # Skip VPN interfaces — use physical default
      skip='wg0|tun[0-9]+|awg[0-9]*'
      def=$(ip -4 route show default 2>/dev/null | grep -vE "$skip" | head -1)
      if [ -z "$def" ]; then
        echo "max-bypass-vpn: no physical default route (VPN already up at boot?)"
        exit 0
      fi
      dev=$(echo "$def" | awk '{print $NF}')
      ip route add table 100 $def 2>/dev/null || true
      ip rule add from 192.168.122.0/24 table 100 priority 100 2>/dev/null || true
      echo "max-bypass-vpn: VM (MAX) traffic via $dev — bypasses VPN"
    '';
  };
}
