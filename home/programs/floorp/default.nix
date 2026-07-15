{ config, lib, pkgs, pkgs-unstable, vars, colors, browser, inputs, ... }:

let
  c = colors.colors;
  rgba = colors.toRgba;
  hmDag = inputs.home-manager.lib.hm.dag;

  # Copies the declaratively-generated theme files into every Floorp profile's
  # chrome/ dir. The profile itself is intentionally NOT Home Manager managed
  # (to preserve tabs/history), so this idempotent copy is how userChrome is
  # applied. Safe to run on every rebuild; never touches tabs or session data.
  floorpApplyTheme = pkgs.writeShellApplication {
    name = "apply-floorp-theme";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep ];
    text = ''
      set -euo pipefail
      floorp_dir="$HOME/.floorp"
      theme_dir="$HOME/.config/floorp-theme"

      if [ ! -d "$floorp_dir" ]; then
        echo "apply-floorp-theme: no profile dir yet ($floorp_dir), skipping"
        exit 0
      fi

      applied=0
      while IFS= read -r -d "" profile; do
        mkdir -p "$profile/chrome"
        cp -f "$theme_dir/userChrome.css" "$profile/chrome/userChrome.css"
        cp -f "$theme_dir/userContent.css" "$profile/chrome/userContent.css"
        if [ -f "$profile/user.js" ]; then
          if ! grep -q "legacyUserProfileCustomizations.stylesheets" "$profile/user.js"; then
            cat "$theme_dir/user.js" >> "$profile/user.js"
          fi
        else
          cp -f "$theme_dir/user.js" "$profile/user.js"
        fi
        applied=$((applied + 1))
      done < <(find "$floorp_dir" -maxdepth 1 -type d -name "*.default*" -print0)

      echo "apply-floorp-theme: applied to $applied profile(s)"
    '';
  };
in
{
  home-manager.users.${vars.username} = {
    # Floorp 12 - Privacy-focused Firefox fork with native transparency and workspaces
    # Package resolved centrally in flake.nix so $browser, exec-once and this
    # install all reference the same derivation.
    # IMPORTANT: We ONLY install the package, NO profile management to preserve tabs!
    # apply-floorp-theme copies the theme into the profile chrome/ dir (see below).
    home.packages = [ browser.package floorpApplyTheme ];

    # user.js for Floorp profile - auto-enables userChrome.css and workspaces
    home.file.".config/floorp-theme/user.js".text = ''
      // ═══════════════════════════════════════════════════════════════════════
      // FLOORP USER PREFERENCES - Applied automatically
      // ═══════════════════════════════════════════════════════════════════════

      // Enable userChrome.css and userContent.css
      user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

      // ─────────────────────────────────────────────────────────────────────────
      // SESSION & STARTUP
      // ─────────────────────────────────────────────────────────────────────────
      // Restore tabs from previous session (CRITICAL - preserves tabs!)
      user_pref("browser.startup.page", 3);  // 3 = restore previous session
      user_pref("browser.sessionstore.resume_from_crash", true);
      user_pref("browser.sessionstore.max_resumed_crashes", 2);

      // ─────────────────────────────────────────────────────────────────────────
      // FLOORP SPECIFIC FEATURES
      // ─────────────────────────────────────────────────────────────────────────
      // Enable Workspaces (Tab Groups/Spaces)
      user_pref("floorp.browser.workspaces.enabled", true);
      user_pref("floorp.browser.workspace.changeWorkspaceWithTabScrollWheel", true);
      user_pref("floorp.browser.workspace.showToolbarWorkspaceButton", true);

      // Enable Vertical Tabs (Tree Style)
      user_pref("floorp.browser.tabs.verticaltab", true);
      user_pref("floorp.verticaltab.width", 250);
      user_pref("floorp.browser.tabs.verticaltab.right", false);

      // Enable Tab Sleep (saves memory for inactive tabs)
      user_pref("floorp.tabsleep.enabled", true);
      user_pref("floorp.tabsleep.tabTimeoutMinutes", 30);

      // Floorp UI Design
      user_pref("floorp.lepton.interface", 3);  // Proton style
      user_pref("floorp.browser.user.interface", 3);  // Modern

      // ─────────────────────────────────────────────────────────────────────────
      // TRANSPARENCY & APPEARANCE
      // ─────────────────────────────────────────────────────────────────────────
      // Dark theme preference
      user_pref("ui.systemUsesDarkTheme", 1);
      user_pref("layout.css.prefers-color-scheme.content-override", 0);  // 0 = dark
      user_pref("browser.in-content.dark-mode", true);

      // Compact mode
      user_pref("browser.compactmode.show", true);
      user_pref("browser.uidensity", 1);  // 1 = compact

      // Smooth scrolling
      user_pref("general.smoothScroll", true);
      user_pref("general.smoothScroll.msdPhysics.enabled", true);

      // Hardware acceleration (for transparency)
      user_pref("gfx.webrender.all", true);
      user_pref("layers.acceleration.force-enabled", true);

      // ─────────────────────────────────────────────────────────────────────────
      // SEARCH ENGINE - DuckDuckGo
      // ─────────────────────────────────────────────────────────────────────────
      user_pref("browser.urlbar.placeholderName", "DuckDuckGo");
      user_pref("browser.urlbar.placeholderName.private", "DuckDuckGo");

      // ─────────────────────────────────────────────────────────────────────────
      // PRIVACY & SECURITY
      // ─────────────────────────────────────────────────────────────────────────
      // Disable telemetry
      user_pref("datareporting.healthreport.uploadEnabled", false);
      user_pref("toolkit.telemetry.enabled", false);
      user_pref("toolkit.telemetry.unified", false);
      user_pref("toolkit.telemetry.archive.enabled", false);

      // Enhanced Tracking Protection
      user_pref("privacy.trackingprotection.enabled", true);
      user_pref("privacy.trackingprotection.socialtracking.enabled", true);
      user_pref("privacy.trackingprotection.cryptomining.enabled", true);
      user_pref("privacy.trackingprotection.fingerprinting.enabled", true);

      // Block third-party cookies
      user_pref("network.cookie.cookieBehavior", 1);

      // DNS over HTTPS (Cloudflare - or change to your preference)
      user_pref("network.trr.mode", 2);
      user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");

      // HTTPS-Only mode
      user_pref("dom.security.https_only_mode", true);
      user_pref("dom.security.https_only_mode_ever_enabled", true);

      // Disable Pocket
      user_pref("extensions.pocket.enabled", false);

      // Disable Firefox accounts
      user_pref("identity.fxaccounts.enabled", false);

      // Don't check default browser
      user_pref("browser.shell.checkDefaultBrowser", false);

      // ─────────────────────────────────────────────────────────────────────────
      // PERFORMANCE
      // ─────────────────────────────────────────────────────────────────────────
      // More content processes (better for many tabs)
      user_pref("dom.ipc.processCount", 8);
      user_pref("dom.ipc.processCount.webIsolated", 4);
    '';

    # userChrome.css - theme-driven dark theme with transparency.
    # All colors derive from the active palette (colors.colors) so the browser
    # chrome follows vars.theme (base16) instead of a hardcoded Catppuccin set.
    home.file.".config/floorp-theme/userChrome.css".text = ''
      /* ═══════════════════════════════════════════════════════════════════════
         FLOORP THEME (theme-driven) WITH TRANSPARENCY
         Palette follows vars.theme via home/themes/colors.nix
         ═══════════════════════════════════════════════════════════════════════ */

      :root {
        /* Active-palette colors */
        --cat-rosewater: ${c.rosewater};
        --cat-flamingo: ${c.flamingo};
        --cat-pink: ${c.pink};
        --cat-mauve: ${c.mauve};
        --cat-red: ${c.red};
        --cat-maroon: ${c.maroon};
        --cat-peach: ${c.peach};
        --cat-yellow: ${c.yellow};
        --cat-green: ${c.green};
        --cat-teal: ${c.teal};
        --cat-sky: ${c.sky};
        --cat-sapphire: ${c.sapphire};
        --cat-blue: ${c.blue};
        --cat-lavender: ${c.lavender};
        --cat-text: ${c.text};
        --cat-subtext1: ${c.subtext1};
        --cat-subtext0: ${c.subtext0};
        --cat-overlay2: ${c.overlay2};
        --cat-overlay1: ${c.overlay1};
        --cat-overlay0: ${c.overlay0};
        --cat-surface2: ${c.surface2};
        --cat-surface1: ${c.surface1};
        --cat-surface0: ${c.surface0};
        --cat-base: ${c.base};
        --cat-mantle: ${c.mantle};
        --cat-crust: ${c.crust};
        --cat-accent: ${c.accent};

        /* Transparency values */
        --transparency-high: 0.35;    /* 35% opacity - very transparent */
        --transparency-medium: 0.5;   /* 50% opacity */
        --transparency-low: 0.7;      /* 70% opacity */

        /* Base colors with transparency (theme-driven) */
        --bg-transparent: ${rgba c.base 0.35};
        --bg-surface: ${rgba c.surface0 0.5};
        --bg-overlay: ${rgba c.surface1 0.7};
        --accent-soft: ${rgba c.accent 0.15};
        --accent-medium: ${rgba c.accent 0.3};

        /* Override Firefox/Floorp theme colors */
        --lwt-accent-color: transparent !important;
        --lwt-accent-color-inactive: transparent !important;
        --toolbar-bgcolor: var(--bg-transparent) !important;
        --toolbar-color: var(--cat-text) !important;
        --tab-selected-bgcolor: var(--bg-surface) !important;
        --tab-loading-fill: var(--cat-accent) !important;
        --urlbar-box-bgcolor: var(--bg-surface) !important;
        --urlbar-box-hover-bgcolor: var(--bg-overlay) !important;
        --arrowpanel-background: var(--bg-transparent) !important;
        --arrowpanel-border-color: var(--cat-surface1) !important;
        --arrowpanel-color: var(--cat-text) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         WINDOW & MAIN BACKGROUND
         ───────────────────────────────────────────────────────────────────────── */
      #main-window,
      #browser,
      #navigator-toolbox {
        background: var(--bg-transparent) !important;
        -moz-appearance: none !important;
      }

      #navigator-toolbox {
        border-bottom: 1px solid var(--accent-soft) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         TAB BAR
         ───────────────────────────────────────────────────────────────────────── */
      #TabsToolbar,
      #titlebar {
        background: transparent !important;
      }

      /* Individual tabs */
      .tabbrowser-tab {
        background: transparent !important;
        margin: 4px 2px !important;
      }

      .tab-background {
        background: transparent !important;
        border-radius: 8px !important;
        transition: background 0.2s ease !important;
      }

      .tabbrowser-tab[selected="true"] .tab-background {
        background: var(--bg-surface) !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3) !important;
      }

      .tabbrowser-tab:hover:not([selected="true"]) .tab-background {
        background: var(--bg-overlay) !important;
      }

      .tab-text {
        color: var(--cat-text) !important;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5) !important;
      }

      /* Tab loading indicator */
      .tabbrowser-tab[busy] .tab-throbber {
        fill: var(--cat-accent) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         URL BAR
         ───────────────────────────────────────────────────────────────────────── */
      #urlbar {
        background: var(--bg-surface) !important;
        border: 1px solid var(--cat-surface1) !important;
        border-radius: 12px !important;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2) !important;
        transition: all 0.2s ease !important;
      }

      #urlbar:focus-within {
        border-color: var(--cat-accent) !important;
        box-shadow: 0 0 0 2px var(--accent-medium),
                    0 4px 12px rgba(0, 0, 0, 0.3) !important;
      }

      #urlbar-input {
        color: var(--cat-text) !important;
      }

      #urlbar-input::placeholder {
        color: var(--cat-overlay1) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         NAVIGATION BAR
         ───────────────────────────────────────────────────────────────────────── */
      #nav-bar {
        background: transparent !important;
        padding: 4px 8px !important;
      }

      /* Toolbar buttons */
      #nav-bar toolbarbutton {
        border-radius: 8px !important;
        transition: background 0.15s ease !important;
      }

      #nav-bar toolbarbutton:hover {
        background: var(--bg-overlay) !important;
      }

      #nav-bar toolbarbutton:active {
        background: var(--cat-surface1) !important;
      }

      /* Back/Forward buttons */
      #back-button,
      #forward-button {
        fill: var(--cat-text) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         VERTICAL TABS (Floorp Sidebar)
         ───────────────────────────────────────────────────────────────────────── */
      #sidebar-box {
        background: var(--bg-transparent) !important;
        border-right: 1px solid var(--accent-soft) !important;
      }

      #sidebar {
        background: transparent !important;
      }

      #sidebar-header {
        background: var(--bg-surface) !important;
        border-bottom: 1px solid var(--cat-surface0) !important;
        padding: 8px !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         WORKSPACES BAR (Tab Groups)
         ───────────────────────────────────────────────────────────────────────── */
      #workspaces-toolbar {
        background: var(--bg-transparent) !important;
      }

      .workspace-button {
        background: transparent !important;
        border-radius: 8px !important;
        margin: 2px !important;
        transition: all 0.15s ease !important;
      }

      .workspace-button:hover {
        background: var(--bg-overlay) !important;
      }

      .workspace-button[selected="true"] {
        background: var(--cat-accent) !important;
        color: var(--cat-crust) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         BOOKMARKS BAR
         ───────────────────────────────────────────────────────────────────────── */
      #PersonalToolbar {
        background: transparent !important;
        padding: 4px 8px !important;
      }

      #PlacesToolbarItems toolbarbutton {
        border-radius: 6px !important;
        padding: 4px 8px !important;
        transition: background 0.15s ease !important;
      }

      #PlacesToolbarItems toolbarbutton:hover {
        background: var(--bg-overlay) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         MENUS & PANELS
         ───────────────────────────────────────────────────────────────────────── */
      menupopup,
      panel,
      .panel-arrowcontent {
        background: var(--bg-transparent) !important;
        border: 1px solid var(--cat-surface1) !important;
        border-radius: 12px !important;
        backdrop-filter: blur(20px) !important;
      }

      menuitem,
      menu {
        color: var(--cat-text) !important;
        border-radius: 6px !important;
        margin: 2px 4px !important;
      }

      menuitem:hover,
      menu:hover {
        background: var(--bg-overlay) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         FINDBAR
         ───────────────────────────────────────────────────────────────────────── */
      findbar {
        background: var(--bg-transparent) !important;
        border-top: 1px solid var(--cat-surface0) !important;
        backdrop-filter: blur(20px) !important;
      }

      .findbar-textbox {
        background: var(--bg-surface) !important;
        border: 1px solid var(--cat-surface1) !important;
        border-radius: 8px !important;
        color: var(--cat-text) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         SCROLLBARS
         ───────────────────────────────────────────────────────────────────────── */
      * {
        scrollbar-color: var(--cat-surface2) transparent !important;
        scrollbar-width: thin !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         NEW TAB BUTTON
         ───────────────────────────────────────────────────────────────────────── */
      #tabs-newtab-button,
      #new-tab-button {
        border-radius: 8px !important;
        transition: all 0.15s ease !important;
      }

      #tabs-newtab-button:hover,
      #new-tab-button:hover {
        background: var(--bg-overlay) !important;
        transform: scale(1.1) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         TAB CLOSE BUTTON
         ───────────────────────────────────────────────────────────────────────── */
      .tab-close-button {
        border-radius: 50% !important;
        transition: all 0.15s ease !important;
      }

      .tab-close-button:hover {
        background: var(--cat-red) !important;
        fill: var(--cat-crust) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         STATUS BAR / BOTTOM
         ───────────────────────────────────────────────────────────────────────── */
      #browser-bottombox {
        background: var(--bg-transparent) !important;
      }

      /* ─────────────────────────────────────────────────────────────────────────
         ANIMATIONS & POLISH
         ───────────────────────────────────────────────────────────────────────── */
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: translateY(0); }
      }

      .tabbrowser-tab {
        animation: fadeIn 0.2s ease !important;
      }
    '';

    # userContent.css - Dark theme for web pages and internal pages
    home.file.".config/floorp-theme/userContent.css".text = ''
      /* Dark theme for Floorp internal pages */

      @-moz-document url("about:blank"),
                     url("about:newtab"),
                     url("about:home"),
                     url("about:privatebrowsing") {
        body {
          background-color: ${colors.colors.base} !important;
          color: ${colors.colors.text} !important;
        }
      }

      @-moz-document url-prefix("about:") {
        :root {
          --in-content-page-background: ${colors.colors.base} !important;
          --in-content-page-color: ${colors.colors.text} !important;
          --in-content-box-background: ${colors.colors.mantle} !important;
          --in-content-box-border-color: ${colors.colors.surface0} !important;
          --in-content-primary-button-background: ${colors.colors.accent} !important;
          --in-content-primary-button-background-hover: ${colors.colors.sapphire} !important;
          --in-content-focus-outline-color: ${colors.colors.accent} !important;
          --card-background-color: ${colors.colors.surface0} !important;
        }
      }

      /* Dark scrollbars for all pages */
      @-moz-document url-prefix("http"), url-prefix("https") {
        * {
          scrollbar-color: ${colors.colors.surface2} transparent !important;
          scrollbar-width: thin !important;
        }
      }
    '';

    # Apply theme automatically on every rebuild so the browser follows the
    # active theme without a manual step. Runs after files are linked; the copy
    # is idempotent and never touches tabs/session data.
    home.activation.applyFloorpTheme = hmDag.entryAfter [ "writeBoundary" ] ''
      run ${floorpApplyTheme}/bin/apply-floorp-theme || true
    '';
  };
}
