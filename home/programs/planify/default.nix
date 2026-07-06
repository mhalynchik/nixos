{ config, pkgs, lib, vars, colors, ... }:

let
in
{
  home-manager.users.${vars.username} = {
    # Planify is installed via home.packages in home.nix

    # GTK4 CSS for Planify with Catppuccin theme and glass effect
    # Planify uses libadwaita, so we create custom CSS
    home.file.".config/planify/gtk4.css".text = ''
      /* Planify Custom Theme - Catppuccin Mocha with Glass Effect */
      /* 60% transparency for glass-like appearance */

      /* Import system color scheme */
      @import url("resource:///org/gnome/Adwaita/styles/base.css");

      /* Color variables */
      @define-color accent_color ${colors.colors.accent};
      @define-color accent_bg_color ${colors.colors.accent};
      @define-color accent_fg_color ${colors.colors.crust};

      @define-color window_bg_color alpha(${colors.colors.base}, 0.6);
      @define-color window_fg_color ${colors.colors.text};

      @define-color view_bg_color alpha(${colors.colors.mantle}, 0.6);
      @define-color view_fg_color ${colors.colors.text};

      @define-color headerbar_bg_color alpha(${colors.colors.crust}, 0.7);
      @define-color headerbar_fg_color ${colors.colors.text};
      @define-color headerbar_border_color alpha(${colors.colors.surface0}, 0.5);
      @define-color headerbar_backdrop_color alpha(${colors.colors.crust}, 0.5);
      @define-color headerbar_shade_color alpha(black, 0.15);

      @define-color sidebar_bg_color alpha(${colors.colors.mantle}, 0.6);
      @define-color sidebar_fg_color ${colors.colors.text};
      @define-color sidebar_backdrop_color alpha(${colors.colors.mantle}, 0.5);
      @define-color sidebar_shade_color alpha(black, 0.1);

      @define-color card_bg_color alpha(${colors.colors.surface0}, 0.6);
      @define-color card_fg_color ${colors.colors.text};
      @define-color card_shade_color alpha(black, 0.1);

      @define-color popover_bg_color alpha(${colors.colors.surface0}, 0.85);
      @define-color popover_fg_color ${colors.colors.text};

      @define-color dialog_bg_color alpha(${colors.colors.base}, 0.9);
      @define-color dialog_fg_color ${colors.colors.text};

      @define-color shade_color alpha(black, 0.15);
      @define-color scrollbar_outline_color alpha(white, 0.1);

      @define-color borders alpha(${colors.colors.surface1}, 0.5);
      @define-color unfocused_borders alpha(${colors.colors.surface0}, 0.3);

      /* Success/Warning/Error colors */
      @define-color success_color ${colors.colors.green};
      @define-color success_bg_color alpha(${colors.colors.green}, 0.2);
      @define-color success_fg_color ${colors.colors.green};

      @define-color warning_color ${colors.colors.yellow};
      @define-color warning_bg_color alpha(${colors.colors.yellow}, 0.2);
      @define-color warning_fg_color ${colors.colors.yellow};

      @define-color error_color ${colors.colors.red};
      @define-color error_bg_color alpha(${colors.colors.red}, 0.2);
      @define-color error_fg_color ${colors.colors.red};

      /* Main window - glass effect */
      window.background {
        background-color: @window_bg_color;
      }

      /* Header bar */
      headerbar {
        background-color: @headerbar_bg_color;
        border-bottom: 1px solid @headerbar_border_color;
        box-shadow: inset 0 -1px @headerbar_shade_color;
      }

      headerbar:backdrop {
        background-color: @headerbar_backdrop_color;
      }

      /* Sidebar */
      .sidebar,
      .navigation-sidebar {
        background-color: @sidebar_bg_color;
        border-right: 1px solid @borders;
      }

      .sidebar:backdrop,
      .navigation-sidebar:backdrop {
        background-color: @sidebar_backdrop_color;
      }

      /* Sidebar rows */
      .sidebar row,
      .navigation-sidebar row {
        border-radius: 8px;
        margin: 2px 6px;
        padding: 8px 12px;
        transition: background-color 150ms ease;
      }

      .sidebar row:hover,
      .navigation-sidebar row:hover {
        background-color: alpha(${colors.colors.surface1}, 0.5);
      }

      .sidebar row:selected,
      .navigation-sidebar row:selected {
        background-color: alpha(@accent_color, 0.3);
        color: @accent_color;
      }

      /* Cards/List items */
      .card,
      list.boxed-list,
      list.content {
        background-color: @card_bg_color;
        border-radius: 12px;
        border: 1px solid @borders;
        box-shadow: 0 1px 3px @card_shade_color;
      }

      /* Task rows */
      row.task-row {
        background-color: transparent;
        border-radius: 8px;
        margin: 4px 8px;
        padding: 12px;
        transition: all 150ms ease;
      }

      row.task-row:hover {
        background-color: alpha(${colors.colors.surface1}, 0.4);
      }

      row.task-row:selected {
        background-color: alpha(@accent_color, 0.2);
      }

      /* Checkboxes */
      checkbutton check {
        border-radius: 50%;
        border: 2px solid ${colors.colors.overlay0};
        background-color: transparent;
        min-width: 22px;
        min-height: 22px;
        transition: all 150ms ease;
      }

      checkbutton check:hover {
        border-color: @accent_color;
        background-color: alpha(@accent_color, 0.1);
      }

      checkbutton check:checked {
        background-color: @accent_color;
        border-color: @accent_color;
        color: @accent_fg_color;
      }

      /* Priority indicators */
      .priority-1 { color: ${colors.colors.red}; }
      .priority-2 { color: ${colors.colors.peach}; }
      .priority-3 { color: ${colors.colors.yellow}; }
      .priority-4 { color: ${colors.colors.blue}; }

      /* Due date badges */
      .due-date {
        background-color: alpha(${colors.colors.surface1}, 0.6);
        border-radius: 6px;
        padding: 4px 8px;
        font-size: 0.85em;
      }

      .due-date.overdue {
        background-color: alpha(${colors.colors.red}, 0.2);
        color: ${colors.colors.red};
      }

      .due-date.today {
        background-color: alpha(${colors.colors.green}, 0.2);
        color: ${colors.colors.green};
      }

      .due-date.upcoming {
        background-color: alpha(${colors.colors.blue}, 0.2);
        color: ${colors.colors.blue};
      }

      /* Buttons */
      button {
        border-radius: 8px;
        padding: 8px 16px;
        transition: all 150ms ease;
      }

      button.suggested-action {
        background-color: @accent_color;
        color: @accent_fg_color;
      }

      button.suggested-action:hover {
        background-color: ${colors.colors.sapphire};
      }

      button.destructive-action {
        background-color: ${colors.colors.red};
        color: ${colors.colors.crust};
      }

      button.circular {
        border-radius: 50%;
        padding: 8px;
      }

      button.flat {
        background-color: transparent;
      }

      button.flat:hover {
        background-color: alpha(${colors.colors.surface1}, 0.5);
      }

      /* Entry fields */
      entry {
        background-color: alpha(${colors.colors.surface0}, 0.5);
        border: 1px solid @borders;
        border-radius: 8px;
        padding: 8px 12px;
        caret-color: @accent_color;
        transition: all 150ms ease;
      }

      entry:focus {
        border-color: @accent_color;
        box-shadow: 0 0 0 2px alpha(@accent_color, 0.2);
      }

      /* Text views */
      textview {
        background-color: transparent;
      }

      textview text {
        background-color: transparent;
      }

      /* Popovers */
      popover.background {
        background-color: @popover_bg_color;
        border: 1px solid @borders;
        border-radius: 12px;
        box-shadow: 0 4px 12px alpha(black, 0.3);
      }

      /* Menu popovers */
      popover.menu {
        padding: 6px;
      }

      popover.menu modelbutton {
        border-radius: 6px;
        padding: 8px 12px;
        transition: background-color 150ms ease;
      }

      popover.menu modelbutton:hover {
        background-color: alpha(${colors.colors.surface1}, 0.5);
      }

      /* Scrollbars */
      scrollbar {
        background-color: transparent;
      }

      scrollbar slider {
        background-color: alpha(${colors.colors.overlay0}, 0.5);
        border-radius: 100px;
        min-width: 8px;
        min-height: 8px;
        transition: all 150ms ease;
      }

      scrollbar slider:hover {
        background-color: alpha(${colors.colors.overlay1}, 0.7);
      }

      scrollbar slider:active {
        background-color: @accent_color;
      }

      /* Progress bars */
      progressbar trough {
        background-color: alpha(${colors.colors.surface1}, 0.5);
        border-radius: 100px;
      }

      progressbar progress {
        background-color: @accent_color;
        border-radius: 100px;
      }

      /* Switches */
      switch {
        background-color: alpha(${colors.colors.surface2}, 0.5);
        border-radius: 100px;
        transition: all 150ms ease;
      }

      switch:checked {
        background-color: @accent_color;
      }

      switch slider {
        background-color: white;
        border-radius: 50%;
        box-shadow: 0 1px 3px alpha(black, 0.2);
      }

      /* Calendar */
      calendar {
        background-color: @card_bg_color;
        border-radius: 12px;
        padding: 8px;
      }

      calendar:selected {
        background-color: @accent_color;
        color: @accent_fg_color;
        border-radius: 50%;
      }

      /* Today indicator */
      calendar.highlight {
        color: @accent_color;
        font-weight: bold;
      }

      /* Labels/Tags */
      .label-tag {
        border-radius: 100px;
        padding: 4px 10px;
        font-size: 0.85em;
        font-weight: 500;
      }

      /* Project colors */
      .project-color {
        border-radius: 50%;
        min-width: 12px;
        min-height: 12px;
      }

      /* Empty state */
      .empty-state {
        color: ${colors.colors.subtext0};
      }

      .empty-state image {
        opacity: 0.5;
      }

      /* Keyboard shortcuts window */
      shortcutswindow {
        background-color: @dialog_bg_color;
      }

      /* Preferences window */
      preferenceswindow {
        background-color: @dialog_bg_color;
      }

      /* Links */
      link {
        color: @accent_color;
      }

      link:hover {
        color: ${colors.colors.sapphire};
      }

      /* Selection */
      selection {
        background-color: alpha(@accent_color, 0.3);
        color: @window_fg_color;
      }

      /* Focus outline */
      *:focus-visible {
        outline: 2px solid alpha(@accent_color, 0.5);
        outline-offset: 2px;
      }

      /* Animations */
      @keyframes fade-in {
        from { opacity: 0; }
        to { opacity: 1; }
      }

      /* Apply smooth transitions globally */
      * {
        transition-property: background-color, border-color, color, opacity, box-shadow;
        transition-duration: 150ms;
        transition-timing-function: ease;
      }
    '';

    # Also create gtk.css in the standard location for GTK4 apps
    home.file.".config/gtk-4.0/planify.css".text = ''
      /* Symlink or import for Planify */
      @import url("file://${vars.homeDirectory}/.config/planify/gtk4.css");
    '';

    # dconf settings for Planify
    dconf.settings = {
      "io/github/alainm23/planify" = {
        # Enable dark theme
        dark-mode = true;
        # Use system accent color
        system-accent-color = true;
        # Enable custom CSS (if supported)
        use-custom-css = true;
      };

      "io/github/alainm23/planify/appearance" = {
        # Font settings
        font = "${colors.fonts.sans}";
        # Color scheme
        color-scheme = "dark";
      };
    };
  };
}
