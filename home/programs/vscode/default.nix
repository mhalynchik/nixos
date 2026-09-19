{ config, pkgs, pkgs-unstable, vars, colors, ... }:

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

      # Stylix installs and selects the palette-derived editor/syntax theme.
      profiles.default.userSettings = {
        "window.autoDetectColorScheme" = false;
        "workbench.colorCustomizations" = {
          "focusBorder" = colors.colors.accent;
          "activityBar.activeBorder" = colors.colors.accent;
        };
      };

      # Other extensions can be installed manually via the VS Code marketplace.
      # Recommended extensions to install:
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
        background-color: ${colors.toRgba colors.colors.base 0.6} !important;
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
        background-color: ${colors.toRgba colors.colors.surface0 0.4} !important;
      }

      /* Sidebar */
      .sidebar,
      .part.sidebar,
      .composite.title {
        background-color: ${colors.toRgba colors.colors.base 0.6} !important;
      }

      /* Activity bar */
      .activitybar,
      .part.activitybar {
        background-color: ${colors.toRgba colors.colors.crust 0.6} !important;
      }

      /* Panel (terminal, output, etc.) */
      .part.panel {
        background-color: ${colors.toRgba colors.colors.base 0.6} !important;
      }

      /* Title bar */
      .part.titlebar {
        background-color: ${colors.toRgba colors.colors.crust 0.6} !important;
      }

      /* Tabs */
      .title.tabs,
      .tabs-container {
        background-color: ${colors.toRgba colors.colors.mantle 0.6} !important;
      }

      .tab {
        background-color: transparent !important;
      }

      .tab.active {
        background-color: ${colors.toRgba colors.colors.base 0.85} !important;
      }

      /* Status bar */
      .statusbar,
      .part.statusbar {
        background-color: ${colors.toRgba colors.colors.crust 0.6} !important;
      }

      /* Minimap */
      .minimap {
        background-color: transparent !important;
      }

      .minimap-slider-horizontal {
        background-color: ${colors.toRgba colors.colors.surface1 0.3} !important;
      }

      /* Scrollbar */
      .monaco-scrollable-element > .scrollbar > .slider {
        background: ${colors.toRgba colors.colors.surface1 0.5} !important;
      }

      /* Explorer / Tree views */
      .monaco-list.list_id_1 .monaco-list-row,
      .monaco-list .monaco-list-row {
        background-color: transparent !important;
      }

      .monaco-list .monaco-list-row.selected {
        background-color: ${colors.toRgba colors.colors.accent 0.2} !important;
      }

      .monaco-list .monaco-list-row:hover:not(.selected) {
        background-color: ${colors.toRgba colors.colors.surface0 0.5} !important;
      }

      /* Quick input / Command palette */
      .quick-input-widget {
        background-color: ${colors.toRgba colors.colors.base 0.95} !important;
      }

      /* Notifications */
      .monaco-workbench .notifications-list-container {
        background-color: ${colors.toRgba colors.colors.base 0.9} !important;
      }

      /* Context menus */
      .context-view .monaco-menu {
        background-color: ${colors.toRgba colors.colors.base 0.95} !important;
      }

      /* Widgets and dialogs */
      .monaco-editor .suggest-widget,
      .monaco-editor .parameter-hints-widget {
        background-color: ${colors.toRgba colors.colors.base 0.95} !important;
      }

      /* Peek view */
      .monaco-editor .peekview-widget .head {
        background-color: ${colors.toRgba colors.colors.base 0.9} !important;
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
        background-color: ${colors.toRgba colors.colors.base 0.9} !important;
      }

      /* Search widget */
      .monaco-editor .find-widget {
        background-color: ${colors.toRgba colors.colors.base 0.95} !important;
      }
    '';
  };
}
