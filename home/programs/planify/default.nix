{ vars, colors, ... }:

{
  home-manager.users.${vars.username} = {
    # Planify reads the standard GTK user stylesheet. Its private named colors
    # supplement the global GTK palette; no unsupported custom-CSS preference.
    gtk.gtk4.extraCss = ''
      @define-color item_border_color ${colors.colors.surface1};
      @define-color upcoming_bg_color ${colors.colors.surface0};
      @define-color upcoming_fg_color ${colors.colors.text};
      @define-color selected_color ${colors.colors.surface1};
    '';
    dconf.settings."io/github/alainm23/planify" = {
      system-appearance = true;
    };
  };
}
