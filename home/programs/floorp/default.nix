{ config, lib, pkgs, pkgs-unstable, vars, colors, ... }:

let
in
{
  home-manager.users.${vars.username} = {
    # Floorp 12 - Privacy-focused Firefox fork with native transparency and workspaces
    # Using unstable for latest version (Floorp 12)
    # Note: floorp was renamed to floorp-bin in nixpkgs starting with version 12.x
    # IMPORTANT: We ONLY install the package, NO profile management to preserve tabs!
    home.packages = [ pkgs-unstable.floorp-bin ];

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

    # userChrome.css - Beautiful dark theme with transparency
    home.file.".config/floorp-theme/userChrome.css".text = ''
      /* ═══════════════════════════════════════════════════════════════════════
         FLOORP CATPPUCCIN MOCHA THEME WITH 60% TRANSPARENCY
         Beautiful, modern, and translucent
         ═══════════════════════════════════════════════════════════════════════ */

      :root {
        /* Catppuccin Mocha Colors */
        --cat-rosewater: #f5e0dc;
        --cat-flamingo: #f2cdcd;
        --cat-pink: #f5c2e7;
        --cat-mauve: #cba6f7;
        --cat-red: #f38ba8;
        --cat-maroon: #eba0ac;
        --cat-peach: #fab387;
        --cat-yellow: #f9e2af;
        --cat-green: #a6e3a1;
        --cat-teal: #94e2d5;
        --cat-sky: #89dceb;
        --cat-sapphire: #74c7ec;
        --cat-blue: #89b4fa;
        --cat-lavender: #b4befe;
        --cat-text: ${colors.colors.text};
        --cat-subtext1: #bac2de;
        --cat-subtext0: ${colors.colors.subtext0};
        --cat-overlay2: #9399b2;
        --cat-overlay1: #7f849c;
        --cat-overlay0: ${colors.colors.overlay0};
        --cat-surface2: ${colors.colors.surface2};
        --cat-surface1: ${colors.colors.surface1};
        --cat-surface0: ${colors.colors.surface0};
        --cat-base: ${colors.colors.base};
        --cat-mantle: ${colors.colors.mantle};
        --cat-crust: ${colors.colors.crust};
        --cat-accent: ${colors.colors.accent};

        /* Transparency values - more transparent! */
        --transparency-high: 0.35;    /* 35% opacity - very transparent */
        --transparency-medium: 0.5;   /* 50% opacity */
        --transparency-low: 0.7;      /* 70% opacity */

        /* Base colors with transparency */
        --bg-transparent: rgba(30, 30, 46, var(--transparency-high));
        --bg-surface: rgba(49, 50, 68, var(--transparency-medium));
        --bg-overlay: rgba(69, 71, 90, var(--transparency-low));

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
        border-bottom: 1px solid rgba(137, 180, 250, 0.2) !important;
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
        background: rgba(69, 71, 90, 0.5) !important;
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
        box-shadow: 0 0 0 2px rgba(137, 180, 250, 0.3),
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
        border-right: 1px solid rgba(137, 180, 250, 0.1) !important;
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

    # Script to apply Floorp theme
    home.file.".local/bin/apply-floorp-theme".source = pkgs.writeShellScript "apply-floorp-theme" ''
      #!/usr/bin/env bash
      # Apply Catppuccin theme to Floorp (fully automated)

      set -e

      FLOORP_DIR="$HOME/.floorp"
      THEME_DIR="$HOME/.config/floorp-theme"

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🦊 Floorp Theme Installer"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""

      if [ ! -d "$FLOORP_DIR" ]; then
        echo "⚠ Floorp profile directory not found at $FLOORP_DIR"
        echo "  Please run Floorp at least once to create a profile."
        exit 1
      fi

      # Find all Floorp profiles
      PROFILES=$(find "$FLOORP_DIR" -maxdepth 1 -type d -name "*.default*")

      if [ -z "$PROFILES" ]; then
        echo "⚠ No Floorp profiles found"
        exit 1
      fi

      for PROFILE in $PROFILES; do
        echo "📁 Applying theme to: $(basename "$PROFILE")"

        # Create chrome directory
        mkdir -p "$PROFILE/chrome"

        # Remove old files (fixes permission issues)
        rm -f "$PROFILE/chrome/userChrome.css" 2>/dev/null || true
        rm -f "$PROFILE/chrome/userContent.css" 2>/dev/null || true

        # Copy theme files
        cp "$THEME_DIR/userChrome.css" "$PROFILE/chrome/"
        cp "$THEME_DIR/userContent.css" "$PROFILE/chrome/"

        # Handle user.js
        if [ -f "$PROFILE/user.js" ]; then
          if ! grep -q "legacyUserProfileCustomizations.stylesheets" "$PROFILE/user.js"; then
            cat "$THEME_DIR/user.js" >> "$PROFILE/user.js"
            echo "   ✓ Appended settings to user.js"
          else
            echo "   ✓ Settings already present in user.js"
          fi
        else
          cp "$THEME_DIR/user.js" "$PROFILE/"
          echo "   ✓ Created user.js"
        fi

        echo "   ✓ Theme files copied"
        echo ""
      done

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "✅ Floorp theme applied successfully!"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      echo "🔄 Please restart Floorp for changes to take effect."
      echo ""
      echo "Features enabled:"
      echo "  • 60% transparent background"
      echo "  • Catppuccin Mocha color scheme"
      echo "  • Workspaces (tab groups)"
      echo "  • Vertical tabs"
      echo "  • Tab sleep (memory saver)"
      echo "  • DuckDuckGo search"
      echo "  • Session restore on startup"
      echo "  • Enhanced privacy protection"
    '';

    home.file.".local/bin/apply-floorp-theme".executable = true;
  };
}
