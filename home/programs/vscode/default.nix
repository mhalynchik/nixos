{ config, pkgs, pkgs-unstable, vars, colors, ... }:

let
  # 60% opacity = 0.6 * 255 = 153 = 0x99
  opacity60 = "99";
  opacity85 = "d9";
  opacity90 = "e6";
  opacity92 = "eb";
in
{
  home-manager.users.${vars.username} = {
    # VS Code with transparency support
    # Using vscode.fhs to allow Custom CSS extension to modify VS Code files
    # Using unstable for latest version
    programs.vscode = {
      enable = true;
      package = pkgs-unstable.vscode.fhs;  # FHS version allows Custom CSS to work

      # Disable mutable extensions to avoid home-manager activation issues
      mutableExtensionsDir = true;

      # profiles.default.userSettings = {
      #   # Custom CSS for transparency (requires "Custom CSS and JS Loader" extension)
      #   "vscode_custom_css.imports" = [
      #     "file://${vars.homeDirectory}/.config/vscode-custom/transparency.css"
      #   ];

      #   # Window settings
      #   "window.titleBarStyle" = "custom";
      #   "window.commandCenter" = true;

      #   # Editor settings
      #   "editor.fontFamily" = "'${colors.fonts.monospace}', 'Droid Sans Mono', monospace";
      #   "editor.fontSize" = colors.fonts.size.large;
      #   "editor.fontLigatures" = true;
      #   "editor.cursorBlinking" = "smooth";
      #   "editor.cursorSmoothCaretAnimation" = "on";
      #   "editor.smoothScrolling" = true;
      #   "editor.minimap.enabled" = true;
      #   "editor.renderWhitespace" = "selection";
      #   "editor.bracketPairColorization.enabled" = true;

      #   # Terminal settings
      #   "terminal.integrated.fontFamily" = colors.fonts.monospace;
      #   "terminal.integrated.fontSize" = colors.fonts.size.normal;

      #   # Workbench - 60% transparency colors (hex with alpha)
      #   "workbench.colorTheme" = "Catppuccin Mocha";
      #   "workbench.iconTheme" = "catppuccin-mocha";
      #   "workbench.colorCustomizations" = {
      #     # Main backgrounds with 60% opacity
      #     "editor.background" = "${colors.colors.base}${opacity60}";
      #     "sideBar.background" = "${colors.colors.base}${opacity60}";
      #     "activityBar.background" = "${colors.colors.crust}${opacity60}";
      #     "statusBar.background" = "${colors.colors.crust}${opacity60}";
      #     "panel.background" = "${colors.colors.base}${opacity60}";
      #     "terminal.background" = "${colors.colors.base}${opacity60}";

      #     # Slightly more opaque for readability
      #     "editorWidget.background" = "${colors.colors.base}${opacity85}";
      #     "input.background" = "${colors.colors.surface0}${opacity85}";
      #     "dropdown.background" = "${colors.colors.surface0}${opacity85}";
      #     "quickInput.background" = "${colors.colors.base}${opacity85}";
      #     "notifications.background" = "${colors.colors.base}${opacity90}";

      #     # Title bar
      #     "titleBar.activeBackground" = "${colors.colors.crust}${opacity60}";
      #     "titleBar.inactiveBackground" = "${colors.colors.crust}${opacity60}";

      #     # Tabs
      #     "tab.activeBackground" = "${colors.colors.base}${opacity85}";
      #     "tab.inactiveBackground" = "${colors.colors.mantle}${opacity60}";
      #     "editorGroupHeader.tabsBackground" = "${colors.colors.mantle}${opacity60}";

      #     # Scrollbar
      #     "scrollbarSlider.background" = "${colors.colors.surface1}80";
      #     "scrollbarSlider.hoverBackground" = "${colors.colors.surface2}a0";
      #     "scrollbarSlider.activeBackground" = "${colors.colors.lavender}c0";

      #     # Border colors
      #     "focusBorder" = colors.colors.accent;
      #     "activityBar.activeBorder" = colors.colors.accent;
      #   };

      #   # Flake8 configuration
      #   "flake8.args" = ["--max-line-length=120"];

      #   # File associations
      #   "files.associations" = {
      #     "*.nix" = "nix";
      #   };

      #   # Git settings
      #   "git.enableSmartCommit" = true;
      #   "git.autofetch" = true;
      #   "yaml.schemas" = {
      #     "file:///${vars.homeDirectory}/.vscode/extensions/continue.continue-1.2.14-linux-x64/config-yaml-schema.json" = [
      #       ".continue/**/*.yaml"
      #     ];
      #   };
      # };

      # Extensions - install manually via VS Code marketplace to avoid activation crashes
      # Recommended extensions to install:
      # - catppuccin.catppuccin-vsc (Theme)
      # - catppuccin.catppuccin-vsc-icons (Icons)
      # - be5invis.vscode-custom-css (REQUIRED for transparency)
      # - github.copilot
      # - github.copilot-chat
      # - eamodio.gitlens
      # - bbenoist.nix
      # - ms-python.python
      # - mhutchie.git-graph
      # - shardulm94.trailing-spaces
      # - gruntfuggly.todo-tree
    };

    # VS Code transparency CSS (for use with Custom CSS extension)
    home.file.".config/vscode-custom/transparency.css".text = ''
      /* VS Code Background Transparency - 60% opacity */
      /* Works with "Custom CSS and JS Loader" extension */
      /* After installing extension, run: Ctrl+Shift+P -> "Enable Custom CSS and JS" */

      /* Main window background */
      body {
        background-color: rgba(30, 30, 46, 0.6) !important;
        background: transparent !important;
      }

      .monaco-workbench {
        background-color: transparent !important;
      }

      /* Editor area */
      .monaco-editor,
      .monaco-editor-background,
      .monaco-editor .margin {
        background-color: transparent !important;
      }

      .monaco-editor .view-overlays .current-line {
        background-color: rgba(49, 50, 68, 0.4) !important;
      }

      /* Sidebar */
      .sidebar,
      .part.sidebar,
      .composite.title {
        background-color: rgba(30, 30, 46, 0.6) !important;
      }

      /* Activity bar */
      .activitybar,
      .part.activitybar {
        background-color: rgba(17, 17, 27, 0.6) !important;
      }

      /* Panel (terminal, output, etc.) */
      .part.panel {
        background-color: rgba(30, 30, 46, 0.6) !important;
      }

      /* Title bar */
      .part.titlebar {
        background-color: rgba(17, 17, 27, 0.6) !important;
      }

      /* Tabs */
      .title.tabs,
      .tabs-container {
        background-color: rgba(24, 24, 37, 0.6) !important;
      }

      .tab {
        background-color: transparent !important;
      }

      .tab.active {
        background-color: rgba(30, 30, 46, 0.85) !important;
      }

      /* Status bar */
      .statusbar,
      .part.statusbar {
        background-color: rgba(17, 17, 27, 0.6) !important;
      }

      /* Minimap */
      .minimap {
        background-color: transparent !important;
      }

      .minimap-slider-horizontal {
        background-color: rgba(69, 71, 90, 0.3) !important;
      }

      /* Scrollbar */
      .monaco-scrollable-element > .scrollbar > .slider {
        background: rgba(69, 71, 90, 0.5) !important;
      }

      /* Explorer / Tree views */
      .monaco-list.list_id_1 .monaco-list-row,
      .monaco-list .monaco-list-row {
        background-color: transparent !important;
      }

      .monaco-list .monaco-list-row.selected {
        background-color: rgba(51, 204, 255, 0.2) !important;
      }

      .monaco-list .monaco-list-row:hover:not(.selected) {
        background-color: rgba(49, 50, 68, 0.5) !important;
      }

      /* Quick input / Command palette */
      .quick-input-widget {
        background-color: rgba(30, 30, 46, 0.95) !important;
      }

      /* Notifications */
      .monaco-workbench .notifications-list-container {
        background-color: rgba(30, 30, 46, 0.9) !important;
      }

      /* Context menus */
      .context-view .monaco-menu {
        background-color: rgba(30, 30, 46, 0.95) !important;
      }

      /* Widgets and dialogs */
      .monaco-editor .suggest-widget,
      .monaco-editor .parameter-hints-widget {
        background-color: rgba(30, 30, 46, 0.95) !important;
      }

      /* Peek view */
      .monaco-editor .peekview-widget .head {
        background-color: rgba(30, 30, 46, 0.9) !important;
      }

      /* Breadcrumbs */
      .monaco-breadcrumbs {
        background-color: transparent !important;
      }

      /* Editor groups */
      .editor-group-container {
        background-color: transparent !important;
      }

      /* Welcome page */
      .monaco-workbench .part.editor > .content .welcomePageContainer {
        background-color: transparent !important;
      }

      /* Settings page */
      .settings-editor {
        background-color: transparent !important;
      }

      /* Extension view */
      .extension-editor {
        background-color: transparent !important;
      }

      /* Debug toolbar */
      .debug-toolbar {
        background-color: rgba(30, 30, 46, 0.9) !important;
      }

      /* Search widget */
      .monaco-editor .find-widget {
        background-color: rgba(30, 30, 46, 0.95) !important;
      }
    '';
  };
}
