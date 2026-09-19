{ config, lib, pkgs, vars, colors, browser, inputs, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
  hmDag = inputs.home-manager.lib.hm.dag;

  librewolfApplyTheme = import ../../../lib/browser-theme.nix {
    inherit pkgs;
    name = "librewolf";
    package = browser.package;
    homeConfig = config.home-manager.users.${vars.username};
  };
in
{
  # Package resolved centrally in flake.nix so $browser, exec-once and this
  # install all reference the same derivation. No profile management.
  home-manager.users.${vars.username} = {
    home.packages = [ browser.package librewolfApplyTheme ];

    # user.js - enables userChrome, dark mode, session restore.
    home.file.".config/librewolf-theme/user.js".text = ''
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      user_pref("browser.startup.page", 3);
      user_pref("ui.systemUsesDarkTheme", 1);
      user_pref("layout.css.prefers-color-scheme.content-override", 0);
      user_pref("browser.in-content.dark-mode", true);
      user_pref("browser.compactmode.show", true);
      user_pref("browser.uidensity", 1);
      user_pref("general.smoothScroll", true);
      user_pref("gfx.webrender.all", true);
      user_pref("browser.shell.checkDefaultBrowser", false);
    '';

    # userChrome.css - theme-driven dark chrome (follows vars.theme / base16).
    home.file.".config/librewolf-theme/userChrome.css".text = ''
      /* LibreWolf theme (theme-driven) - palette from home/themes/colors.nix */
      :root {
        --lw-base: ${c.base};
        --lw-mantle: ${c.mantle};
        --lw-surface0: ${c.surface0};
        --lw-surface1: ${c.surface1};
        --lw-surface2: ${c.surface2};
        --lw-text: ${c.text};
        --lw-subtext: ${c.subtext0};
        --lw-accent: ${c.accent};

        --lw-bg: ${rgba c.base 0.85};
        --lw-bg-surface: ${rgba c.surface0 0.6};
        --lw-bg-overlay: ${rgba c.surface1 0.75};
        --lw-accent-soft: ${rgba c.accent 0.15};
        --lw-accent-medium: ${rgba c.accent 0.3};

        --lwt-accent-color: var(--lw-base) !important;
        --lwt-accent-color-inactive: var(--lw-mantle) !important;
        --toolbar-bgcolor: var(--lw-bg) !important;
        --toolbar-color: var(--lw-text) !important;
        --tab-selected-bgcolor: var(--lw-bg-surface) !important;
        --urlbar-box-bgcolor: var(--lw-bg-surface) !important;
        --arrowpanel-background: var(--lw-bg) !important;
        --arrowpanel-color: var(--lw-text) !important;
        --arrowpanel-border-color: var(--lw-surface1) !important;
      }

      #main-window,
      #browser,
      #navigator-toolbox {
        background: var(--lw-bg) !important;
      }

      #navigator-toolbox {
        border-bottom: 1px solid var(--lw-accent-soft) !important;
      }

      #TabsToolbar,
      #titlebar {
        background: transparent !important;
      }

      .tabbrowser-tab {
        margin: 3px 2px !important;
      }

      .tab-background {
        background: transparent !important;
        border-radius: 8px !important;
        transition: background 0.2s ease !important;
      }

      .tabbrowser-tab[selected="true"] .tab-background {
        background: var(--lw-bg-surface) !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3) !important;
      }

      .tabbrowser-tab:hover:not([selected="true"]) .tab-background {
        background: var(--lw-bg-overlay) !important;
      }

      .tab-text {
        color: var(--lw-text) !important;
      }

      #urlbar {
        background: var(--lw-bg-surface) !important;
        border: 1px solid var(--lw-surface1) !important;
        border-radius: 12px !important;
        transition: all 0.2s ease !important;
      }

      #urlbar:focus-within {
        border-color: var(--lw-accent) !important;
        box-shadow: 0 0 0 2px var(--lw-accent-medium) !important;
      }

      #urlbar-input {
        color: var(--lw-text) !important;
      }

      #urlbar-input::placeholder {
        color: var(--lw-subtext) !important;
      }

      #nav-bar {
        background: transparent !important;
        padding: 4px 8px !important;
      }

      #nav-bar toolbarbutton {
        border-radius: 8px !important;
        transition: background 0.15s ease !important;
      }

      #nav-bar toolbarbutton:hover {
        background: var(--lw-bg-overlay) !important;
      }

      #PersonalToolbar {
        background: transparent !important;
        padding: 4px 8px !important;
      }

      menupopup,
      panel,
      .panel-arrowcontent {
        background: var(--lw-bg) !important;
        border: 1px solid var(--lw-surface1) !important;
        border-radius: 12px !important;
      }

      menuitem,
      menu {
        color: var(--lw-text) !important;
        border-radius: 6px !important;
        margin: 2px 4px !important;
      }

      menuitem:hover,
      menu:hover {
        background: var(--lw-bg-overlay) !important;
      }

      #tabs-newtab-button:hover,
      #new-tab-button:hover {
        background: var(--lw-bg-overlay) !important;
      }

      .tab-close-button:hover {
        background: var(--lw-accent) !important;
      }

      * {
        scrollbar-color: var(--lw-surface2) transparent !important;
        scrollbar-width: thin !important;
      }
    '';

    # userContent.css - dark internal (about:) pages.
    home.file.".config/librewolf-theme/userContent.css".text = ''
      @-moz-document url("about:blank"),
                     url("about:newtab"),
                     url("about:home"),
                     url("about:privatebrowsing") {
        body {
          background-color: ${c.base} !important;
          color: ${c.text} !important;
        }
      }

      @-moz-document url-prefix("about:") {
        :root {
          --in-content-page-background: ${c.base} !important;
          --in-content-page-color: ${c.text} !important;
          --in-content-box-background: ${c.mantle} !important;
          --in-content-box-border-color: ${c.surface0} !important;
          --in-content-primary-button-background: ${c.accent} !important;
          --in-content-focus-outline-color: ${c.accent} !important;
          --card-background-color: ${c.surface0} !important;
        }
      }

      @-moz-document url-prefix("http"), url-prefix("https") {
        * {
          scrollbar-color: ${c.surface2} transparent !important;
          scrollbar-width: thin !important;
        }
      }
    '';

    # Apply theme automatically on every rebuild (idempotent; preserves tabs).
    home.activation.applyLibrewolfTheme = hmDag.entryAfter [ "linkGeneration" ] ''
      run ${librewolfApplyTheme}/bin/apply-librewolf-theme
    '';
  };
}
