{ config, lib, pkgs, vars, colors, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
  popupTimeout = vars.agsPopupTimeout or 3;

  # AGS configuration - popup widgets for waybar
  agsConfig = pkgs.writeText "config.js" ''
    // AGS Popup Widgets for Waybar
    // Toggle windows with: ags -t <window-name>

    const hyprland = await Service.import("hyprland");
    const network = await Service.import("network");
    const bluetooth = await Service.import("bluetooth");
    const audio = await Service.import("audio");

    // Helper to get current monitor (where cursor is)
    function getCurrentMonitor() {
      try {
        const focusedMonitor = hyprland.monitors.find(m => m.focused);
        return focusedMonitor ? focusedMonitor.id : 0;
      } catch(e) { return 0; }
    }

    // All popup window names
    const POPUPS = ["calendar-popup", "system-stats-popup", "network-popup", "audio-popup", "bluetooth-popup", "keyboard-popup"];

    // Close all popups except the specified one (safe version)
    function closeOtherPopups(exceptName) {
      const windows = App.windows || [];
      POPUPS.forEach(name => {
        if (name !== exceptName) {
          const win = windows.find(w => w.name === name);
          if (win && win.visible) {
            App.closeWindow(name);
          }
        }
      });
    }

    // Auto-close timeout (ms) - from vars.nix
    const AUTO_CLOSE_DELAY = ${toString popupTimeout} * 1000;
    let autoCloseTimers = {};

    function setupAutoClose(windowName) {
      cancelAutoClose(windowName);
      autoCloseTimers[windowName] = setTimeout(() => {
        const win = (App.windows || []).find(w => w.name === windowName);
        if (win && win.visible) {
          App.closeWindow(windowName);
        }
      }, AUTO_CLOSE_DELAY);
    }

    function cancelAutoClose(windowName) {
      if (autoCloseTimers[windowName]) {
        clearTimeout(autoCloseTimers[windowName]);
        autoCloseTimers[windowName] = null;
      }
    }

    // Track if window was opened by user (not initial setup)
    let windowInitialized = {};

    // Common popup window setup with multi-monitor support
    function setupPopupWindow(self, windowName) {
      windowInitialized[windowName] = false;
      self.keybind("Escape", () => App.closeWindow(windowName));
      self.connect("notify::visible", () => {
        if (self.visible) {
          // Move popup to current monitor when opened
          self.gdkmonitor = getCurrentMonitor();
          if (windowInitialized[windowName]) {
            closeOtherPopups(windowName);
          }
          windowInitialized[windowName] = true;
          setupAutoClose(windowName);
        } else {
          cancelAutoClose(windowName);
        }
      });
    }

    // Hover tracking widget wrapper - cancels auto-close while hovering
    function HoverBox(windowName, props) {
      return Widget.EventBox({
        onHover: () => cancelAutoClose(windowName),
        onHoverLost: () => setupAutoClose(windowName),
        child: Widget.Box(props),
      });
    }

    // ============================================
    // Variables
    // ============================================

    const date = Variable("", {
      poll: [60000, ["date", "+%A, %d %B %Y"], out => out.trim()],
    });

    const cpu = Variable(0, {
      poll: [2000, ["bash", "-c", "cat /proc/stat | head -1"], out => {
        try {
          const values = out.split(/\s+/).slice(1).map(Number);
          const idle = values[3] || 0;
          const total = values.reduce((a, b) => a + b, 0) || 1;
          return Math.round((1 - idle / total) * 100);
        } catch(e) { return 0; }
      }],
    });

    const ram = Variable({ used: 0, total: 0, percent: 0 }, {
      poll: [2000, ["bash", "-c", "free -b | grep Mem"], out => {
        try {
          const values = out.split(/\s+/).map(Number);
          const total = values[1] || 1;
          const used = values[2] || 0;
          return {
            used: Math.round(used / 1024 / 1024 / 1024 * 10) / 10,
            total: Math.round(total / 1024 / 1024 / 1024 * 10) / 10,
            percent: Math.round((used / total) * 100),
          };
        } catch(e) { return { used: 0, total: 0, percent: 0 }; }
      }],
    });

    const cpuTemp = Variable(0, {
      poll: [3000, ["bash", "-c", "cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 || echo 0"], out => {
        try { return Math.round(parseInt(out) / 1000) || 0; } catch(e) { return 0; }
      }],
    });

    const gpuTemp = Variable(0, {
      poll: [3000, ["bash", "-c", "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0"], out => {
        try { return parseInt(out.trim()) || 0; } catch(e) { return 0; }
      }],
    });

    const kbLayout = Variable("EN", {
      poll: [500, ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -1"], out => {
        const layout = out.trim().toLowerCase();
        if (layout.includes("russian")) return "RU";
        if (layout.includes("english")) return "EN";
        return layout.substring(0, 2).toUpperCase();
      }],
    });

    // Audio sinks list
    const audioSinks = Variable([], {
      poll: [5000, ["bash", "-c", "command -v pactl >/dev/null && pactl list sinks short || true"], out => {
        try {
          return out.trim().split("\\n").filter(l => l).map(line => {
            const parts = line.split("\\t");
            return { id: parts[0], name: parts[1] || "Unknown", state: parts[4] || "IDLE" };
          });
        } catch(e) { return []; }
      }],
    });

    // ============================================
    // Calendar Popup Widget
    // ============================================

    function CalendarPopup() {
      return Widget.Window({
        name: "calendar-popup",
        className: "popup-window",
        anchor: ["top"],
        margins: [50, 0, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("calendar-popup", {
          className: "calendar-box",
          vertical: true,
          children: [
            Widget.Label({ className: "calendar-date", label: date.bind() }),
            Widget.Calendar({ className: "calendar", showDayNames: true, showHeading: true, showWeekNumbers: true }),
          ],
        }),
        setup: self => setupPopupWindow(self, "calendar-popup"),
      });
    }

    // ============================================
    // System Stats Popup Widget
    // ============================================

    function SystemStatsPopup() {
      return Widget.Window({
        name: "system-stats-popup",
        className: "popup-window",
        anchor: ["top", "right"],
        margins: [50, 10, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("system-stats-popup", {
          className: "system-stats-box",
          vertical: true,
          spacing: 8,
          children: [
            Widget.Label({ className: "popup-title", label: "System Monitor" }),
            Widget.Box({
              className: "stat-section",
              vertical: true,
              children: [
                Widget.Box({ className: "stat-row", children: [
                  Widget.Label({ className: "stat-icon", label: "󰍛", css: "color: #f5c2e7;" }),
                  Widget.Label({ className: "stat-label", label: "CPU" }),
                  Widget.Box({ hexpand: true }),
                  Widget.Label({ className: "stat-value", label: cpu.bind().as(v => v + "%") }),
                ]}),
                Widget.LevelBar({ className: "stat-bar cpu-bar", value: cpu.bind().as(v => v / 100) }),
              ],
            }),
            Widget.Box({
              className: "stat-section",
              vertical: true,
              children: [
                Widget.Box({ className: "stat-row", children: [
                  Widget.Label({ className: "stat-icon", label: "󰻠", css: "color: #b5e8e0;" }),
                  Widget.Label({ className: "stat-label", label: "RAM" }),
                  Widget.Box({ hexpand: true }),
                  Widget.Label({ className: "stat-value", label: ram.bind().as(v => v.used + "G / " + v.total + "G") }),
                ]}),
                Widget.LevelBar({ className: "stat-bar ram-bar", value: ram.bind().as(v => v.percent / 100) }),
              ],
            }),
            Widget.Box({
              className: "stat-section",
              vertical: true,
              children: [
                Widget.Box({ className: "stat-row", children: [
                  Widget.Label({ className: "stat-icon", label: "󰈸", css: "color: #96cdfe;" }),
                  Widget.Label({ className: "stat-label", label: "CPU Temp" }),
                  Widget.Box({ hexpand: true }),
                  Widget.Label({ className: "stat-value", label: cpuTemp.bind().as(v => v + "°C") }),
                ]}),
                Widget.Box({ className: "stat-row", children: [
                  Widget.Label({ className: "stat-icon", label: "󰢮", css: "color: #89b4fa;" }),
                  Widget.Label({ className: "stat-label", label: "GPU Temp" }),
                  Widget.Box({ hexpand: true }),
                  Widget.Label({ className: "stat-value", label: gpuTemp.bind().as(v => v > 0 ? v + "°C" : "N/A") }),
                ]}),
              ],
            }),
          ],
        }),
        setup: self => setupPopupWindow(self, "system-stats-popup"),
      });
    }

    // ============================================
    // Network/WiFi Popup Widget
    // ============================================

    function NetworkPopup() {
      return Widget.Window({
        name: "network-popup",
        className: "popup-window",
        anchor: ["top", "right"],
        margins: [50, 10, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("network-popup", {
          className: "network-box",
          vertical: true,
          spacing: 8,
          children: [
            Widget.Label({ className: "popup-title", label: "Network" }),
            Widget.Button({
              className: "toggle-button",
              onClicked: () => network.wifi.enabled = !network.wifi.enabled,
              child: Widget.Box({ children: [
                Widget.Icon({ icon: "network-wireless-symbolic" }),
                Widget.Label({ label: "  Wi-Fi" }),
                Widget.Box({ hexpand: true }),
                Widget.Switch({
                  active: network.wifi.bind("enabled"),
                  onActivate: ({ active }) => network.wifi.enabled = active,
                }),
              ]}),
            }),
            Widget.Separator(),
            Widget.Box({
              className: "wifi-list",
              vertical: true,
              vexpand: true,
              children: network.wifi.bind("access_points").as(aps =>
                aps
                  .filter(ap => ap.ssid)
                  .sort((a, b) => b.strength - a.strength)
                  .slice(0, 8)
                  .map(ap => Widget.Button({
                    className: ap.active ? "wifi-network active" : "wifi-network",
                    onClicked: () => { if (!ap.active) Utils.execAsync(["nmcli", "device", "wifi", "connect", ap.ssid]); },
                    child: Widget.Box({ children: [
                      Widget.Icon({ icon: ap.iconName }),
                      Widget.Label({ label: "  " + (ap.ssid || "Hidden") }),
                      Widget.Box({ hexpand: true }),
                      Widget.Label({ label: ap.strength + "%" }),
                      ap.active ? Widget.Label({ className: "connected-badge", label: " 󰄬" }) : Widget.Label({ label: "" }),
                    ]}),
                  }))
              ),
            }),
            Widget.Button({
              className: "settings-button",
              label: "Open Network Settings",
              onClicked: () => Utils.execAsync("nm-connection-editor"),
            }),
          ],
        }),
        setup: self => setupPopupWindow(self, "network-popup"),
      });
    }

    // ============================================
    // Bluetooth Popup Widget - Fixed with bluetoothctl
    // ============================================

    function BluetoothPopup() {
      const btDevices = Variable([], {
        poll: [5000, ["bash", "-c", "timeout 2 bluetoothctl devices 2>/dev/null || true"], out => {
          try {
            if (!out || !out.trim()) return [];
            const lines = out.trim().split("\n");
            return lines
              .filter(l => l && l.startsWith("Device"))
              .map(line => {
                const match = line.match(/^Device ([A-F0-9:]+) (.+)$/i);
                if (match) {
                  const mac = match[1];
                  const name = match[2];
                  // Skip if name looks like MAC address
                  if (name.match(/^[A-F0-9][A-F0-9][-:][A-F0-9][A-F0-9][-:]/i)) return null;
                  return { mac, name };
                }
                return null;
              })
              .filter(d => d !== null);
          } catch(e) { return []; }
        }],
      });

      const btConnected = Variable([], {
        poll: [5000, ["bash", "-c", "timeout 2 bluetoothctl devices Connected 2>/dev/null || true"], out => {
          try {
            if (!out || !out.trim()) return [];
            const lines = out.trim().split("\n");
            return lines
              .filter(l => l && l.startsWith("Device"))
              .map(line => {
                const match = line.match(/^Device ([A-F0-9:]+)/i);
                return match ? match[1] : null;
              })
              .filter(m => m !== null);
          } catch(e) { return []; }
        }],
      });

      const btEnabled = Variable(false, {
        poll: [3000, ["bash", "-c", "timeout 1 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"], out => {
          return out.trim() === "on";
        }],
      });

      const toggleBluetooth = () => {
        if (btEnabled.value) {
          Utils.execAsync(["bluetoothctl", "power", "off"]).catch(() => {});
        } else {
          Utils.execAsync(["bluetoothctl", "power", "on"]).catch(() => {});
        }
      };

      return Widget.Window({
        name: "bluetooth-popup",
        className: "popup-window",
        anchor: ["top", "right"],
        margins: [50, 10, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("bluetooth-popup", {
          className: "bluetooth-box",
          vertical: true,
          spacing: 8,
          children: [
            Widget.Label({ className: "popup-title", label: "Bluetooth" }),
            Widget.Button({
              className: "toggle-button",
              onClicked: toggleBluetooth,
              child: Widget.Box({ children: [
                Widget.Icon({ icon: "bluetooth-symbolic" }),
                Widget.Label({ label: "  Bluetooth" }),
                Widget.Box({ hexpand: true }),
                Widget.Label({ className: btEnabled.bind().as(e => e ? "status-on" : "status-off"), label: btEnabled.bind().as(e => e ? "ON" : "OFF") }),
              ]}),
            }),
            Widget.Separator(),
            Widget.Box({
              className: "bt-list",
              vertical: true,
              vexpand: true,
              children: Utils.merge([btDevices.bind(), btConnected.bind()], (devices, connected) =>
                devices.map(d => Widget.Button({
                  className: connected.includes(d.mac) ? "bt-device connected" : "bt-device",
                  onClicked: () => {
                    if (connected.includes(d.mac)) {
                      Utils.execAsync(["bluetoothctl", "disconnect", d.mac]).catch(() => {});
                    } else {
                      Utils.execAsync(["bluetoothctl", "connect", d.mac]).catch(() => {});
                    }
                  },
                  child: Widget.Box({ children: [
                    Widget.Icon({ icon: "bluetooth-symbolic" }),
                    Widget.Label({ label: "  " + d.name }),
                    Widget.Box({ hexpand: true }),
                    connected.includes(d.mac) ? Widget.Label({ className: "connected-badge", label: "󰄬" }) : Widget.Label({ label: "" }),
                  ]}),
                }))
              ),
            }),
            Widget.Button({
              className: "settings-button",
              label: "Open Bluetooth Settings",
              onClicked: () => Utils.execAsync("blueman-manager").catch(() => {}),
            }),
          ],
        }),
        setup: self => setupPopupWindow(self, "bluetooth-popup"),
      });
    }

    // ============================================
    // Audio Popup Widget with Sink Selection
    // ============================================

    function AudioPopup() {
      return Widget.Window({
        name: "audio-popup",
        className: "popup-window",
        anchor: ["top", "right"],
        margins: [50, 10, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("audio-popup", {
          className: "audio-box",
          vertical: true,
          spacing: 8,
          children: [
            Widget.Label({ className: "popup-title", label: "Audio Output" }),
            // Main volume control
            Widget.Box({
              className: "volume-main",
              children: [
                Widget.Button({
                  className: "volume-icon",
                  child: Widget.Icon({
                    icon: audio.speaker.bind("is_muted").as(m => m ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"),
                  }),
                  onClicked: () => audio.speaker.is_muted = !audio.speaker.is_muted,
                }),
                Widget.Slider({
                  className: "volume-slider",
                  hexpand: true,
                  drawValue: false,
                  value: audio.speaker.bind("volume"),
                  onChange: ({ value }) => audio.speaker.volume = value,
                }),
                Widget.Label({
                  className: "volume-label",
                  label: audio.speaker.bind("volume").as(v => Math.round(v * 100) + "%"),
                }),
              ],
            }),
            // Output devices
            Widget.Label({ className: "section-title", label: "Output Devices" }),
            Widget.Box({
              className: "sinks-list",
              vertical: true,
              children: audio.bind("speakers").as(speakers =>
                speakers.map(sink => Widget.Button({
                  className: sink.is_default ? "sink-item default" : "sink-item",
                  onClicked: () => {
                    Utils.execAsync(["pactl", "set-default-sink", sink.name]);
                  },
                  child: Widget.Box({ children: [
                    Widget.Icon({ icon: "audio-card-symbolic" }),
                    Widget.Label({
                      label: "  " + (sink.description || sink.name).substring(0, 25),
                      truncate: "end",
                    }),
                    Widget.Box({ hexpand: true }),
                    sink.is_default ? Widget.Label({ className: "connected-badge", label: "󰄬" }) : Widget.Label({ label: "" }),
                  ]}),
                }))
              ),
            }),
            Widget.Separator(),
            // Microphone
            Widget.Label({ className: "section-title", label: "Microphone" }),
            Widget.Box({
              className: "volume-main mic",
              children: [
                Widget.Button({
                  className: "volume-icon",
                  child: Widget.Icon({
                    icon: audio.microphone.bind("is_muted").as(m => m ? "microphone-disabled-symbolic" : "audio-input-microphone-symbolic"),
                  }),
                  onClicked: () => audio.microphone.is_muted = !audio.microphone.is_muted,
                }),
                Widget.Slider({
                  className: "volume-slider",
                  hexpand: true,
                  drawValue: false,
                  value: audio.microphone.bind("volume"),
                  onChange: ({ value }) => audio.microphone.volume = value,
                }),
                Widget.Label({
                  className: "volume-label",
                  label: audio.microphone.bind("volume").as(v => Math.round(v * 100) + "%"),
                }),
              ],
            }),
            Widget.Separator(),
            Widget.Box({
              className: "audio-buttons",
              homogeneous: true,
              spacing: 8,
              children: [
                Widget.Button({
                  className: "settings-button",
                  label: "󰕾 pavucontrol",
                  onClicked: () => Utils.execAsync("pavucontrol"),
                }),
                Widget.Button({
                  className: "settings-button",
                  label: "󰎈 pulsemixer",
                  onClicked: () => Utils.execAsync(["kitty", "--class", "floating", "-e", "pulsemixer"]),
                }),
              ],
            }),
          ],
        }),
        setup: self => setupPopupWindow(self, "audio-popup"),
      });
    }

    // ============================================
    // Keyboard Layout Popup Widget
    // ============================================

    function KeyboardPopup() {
      return Widget.Window({
        name: "keyboard-popup",
        className: "popup-window",
        anchor: ["top", "right"],
        margins: [50, 10, 0, 0],
        visible: false,
        keymode: "on-demand",
        child: HoverBox("keyboard-popup", {
          className: "keyboard-box",
          vertical: true,
          spacing: 8,
          children: [
            Widget.Label({ className: "popup-title", label: "Keyboard Layout" }),
            Widget.Box({
              className: "layout-display",
              children: [
                Widget.Label({ className: "layout-icon", label: "󰌌" }),
                Widget.Label({ className: "layout-current", label: kbLayout.bind() }),
              ],
            }),
            Widget.Button({
              className: "layout-button",
              label: "🇺🇸 English (US)",
              onClicked: () => {
                Utils.execAsync(["hyprctl", "switchxkblayout", "all", "0"]);
                App.closeWindow("keyboard-popup");
              },
            }),
            Widget.Button({
              className: "layout-button",
              label: "🇷🇺 Russian",
              onClicked: () => {
                Utils.execAsync(["hyprctl", "switchxkblayout", "all", "1"]);
                App.closeWindow("keyboard-popup");
              },
            }),
          ],
        }),
        setup: self => setupPopupWindow(self, "keyboard-popup"),
      });
    }

    // ============================================
    // App Configuration
    // ============================================

    App.config({
      style: App.configDir + "/style.css",
      windows: [
        CalendarPopup(),
        SystemStatsPopup(),
        NetworkPopup(),
        BluetoothPopup(),
        AudioPopup(),
        KeyboardPopup(),
      ],
    });

    export {};
  '';

  # AGS stylesheet for popup widgets - using dynamic theme colors
  agsStyle = pkgs.writeText "style.css" ''
    /* AGS Popup Widgets Stylesheet - Theme: ${colors.displayName} */

    * {
      all: unset;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
    }

    .popup-window {
      background-color: ${rgba c.base 0.95};
      border: 2px solid ${rgba c.accent 0.4};
      border-radius: 12px;
      padding: 16px;
      min-width: 280px;
    }

    .popup-title {
      font-size: 16px;
      font-weight: bold;
      color: ${c.text};
      margin-bottom: 12px;
    }

    .section-title {
      font-size: 12px;
      color: ${c.overlay1};
      margin: 8px 0 4px 0;
    }

    .calendar-box { padding: 8px; }
    .calendar-date { font-size: 14px; color: ${c.blue}; margin-bottom: 12px; }
    .calendar { background-color: transparent; color: ${c.text}; }

    .system-stats-box { min-width: 280px; }

    .stat-section {
      background-color: ${rgba c.surface0 0.5};
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 8px;
    }

    .stat-row { margin-bottom: 8px; }
    .stat-icon { font-size: 18px; margin-right: 10px; }
    .stat-label { color: ${c.subtext1}; }
    .stat-value { color: ${c.text}; font-weight: bold; }

    .stat-bar, .stat-bar trough {
      min-height: 6px;
      border-radius: 3px;
      background-color: ${rgba c.surface2 0.8};
    }

    .cpu-bar block.filled { background-color: ${c.pink}; border-radius: 3px; }
    .ram-bar block.filled { background-color: ${c.teal}; border-radius: 3px; }

    .network-box, .bluetooth-box { min-width: 280px; }

    .toggle-button {
      padding: 10px 12px;
      border-radius: 8px;
      background-color: ${rgba c.surface0 0.5};
    }

    .toggle-button:hover { background-color: ${rgba c.surface0 0.8}; }

    .toggle-button switch {
      min-width: 40px;
      min-height: 20px;
      border-radius: 10px;
      background-color: ${c.surface2};
    }

    .toggle-button switch:checked { background-color: ${rgba c.accent 0.6}; }

    .toggle-button switch slider {
      min-width: 16px;
      min-height: 16px;
      border-radius: 8px;
      background-color: ${c.text};
    }

    separator {
      background-color: ${rgba c.surface2 0.5};
      min-height: 1px;
      margin: 8px 0;
    }

    .wifi-list, .bt-list, .sinks-list { min-height: 100px; }

    .wifi-network, .bt-device, .sink-item {
      padding: 10px 12px;
      border-radius: 8px;
      margin: 2px 0;
    }

    .wifi-network:hover, .bt-device:hover, .sink-item:hover { background-color: ${rgba c.surface0 0.5}; }
    .wifi-network.active, .bt-device.connected, .sink-item.default { background-color: ${rgba c.accent 0.15}; }

    .connected-badge { color: ${c.green}; }

    .settings-button {
      padding: 10px;
      border-radius: 8px;
      background-color: ${rgba c.accent 0.2};
      color: ${c.accent};
      margin-top: 8px;
    }

    .settings-button:hover { background-color: ${rgba c.accent 0.3}; }

    .audio-box { min-width: 300px; }

    .volume-main {
      background-color: ${rgba c.surface0 0.5};
      padding: 12px;
      border-radius: 8px;
    }

    .volume-main.mic { margin-bottom: 8px; }

    .volume-icon { padding: 4px 8px; border-radius: 4px; }
    .volume-icon:hover { background-color: ${rgba c.accent 0.2}; }

    .volume-slider { min-width: 150px; margin: 0 10px; }

    .volume-slider trough {
      min-height: 6px;
      border-radius: 3px;
      background-color: ${rgba c.surface2 0.8};
    }

    .volume-slider highlight {
      border-radius: 3px;
      background-color: ${rgba c.accent 0.8};
    }

    .volume-slider slider {
      min-width: 14px;
      min-height: 14px;
      border-radius: 7px;
      background-color: ${c.accent};
      margin: -4px 0;
    }

    .volume-label { min-width: 45px; color: ${c.text}; }

    .audio-buttons { margin-top: 8px; }

    .keyboard-box { min-width: 220px; }

    .layout-display {
      background-color: ${rgba c.surface0 0.5};
      padding: 16px;
      border-radius: 8px;
      margin-bottom: 8px;
    }

    .layout-icon { font-size: 24px; margin-right: 12px; color: ${c.accent}; }
    .layout-current { font-size: 28px; font-weight: bold; color: ${c.text}; }

    .layout-button {
      padding: 12px;
      border-radius: 8px;
      background-color: ${rgba c.surface0 0.3};
      color: ${c.text};
      margin: 4px 0;
    }

    .layout-button:hover { background-color: ${rgba c.accent 0.2}; }

    .status-on { color: ${c.green}; font-weight: bold; }
    .status-off { color: ${c.overlay1}; }
  '';
in
{
  home-manager.users.${vars.username} = {
    home.packages = with pkgs; [
      ags_1
      libdbusmenu-gtk3
      libsoup_3
      gvfs
      upower
      networkmanager
      bluez
      blueman
      pavucontrol
      jq
      pulseaudio  # for pactl
    ];

    home.sessionVariables = {
      GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [
        libdbusmenu-gtk3
        libsoup_3
        gvfs
        upower
        networkmanager
        gtk3
        gdk-pixbuf
        pango
        gobject-introspection
      ]);
    };

    xdg.configFile = {
      "ags/config.js".source = agsConfig;
      "ags/style.css".source = agsStyle;
    };
  };
}
