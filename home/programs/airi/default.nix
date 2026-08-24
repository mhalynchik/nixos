{ pkgs, vars, inputs, ... }:

# AIRI desktop from flake input. Vanilla v0.12.0-beta.1 does not build:
# fetchPnpmDeps times out, electron-builder 26.8.1 rejects pnpm overrides.
# Overlay is the E0 launch fix, not an AIRI fork.
let
  airi = inputs.airi.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    pnpmDeps = old.pnpmDeps.override {
      prePnpmInstall = ''
        pnpm config set fetch-timeout 600000
        pnpm config set fetch-retries 10
        pnpm config set network-concurrency 2
        export pnpm_config_fetch_timeout=600000
        export pnpm_config_fetch_retries=10
        export pnpm_config_network_concurrency=2
      '';
    };

    preBuild = ''
      mkdir -p engines/stage-tamagotchi-godot/out/linux
      mkdir -p engines/stage-tamagotchi-godot/out/mac

      node <<'EOF'
      const fs = require("fs");
      const { execSync } = require("child_process");

      function patchFile(file, pairs) {
        let text = fs.readFileSync(file, "utf8");
        for (const [from, to] of pairs) {
          if (!text.includes(from)) {
            throw new Error("patch needle missing in " + file + ": " + from.slice(0, 80));
          }
          text = text.replace(from, to);
        }
        fs.writeFileSync(file, text);
      }

      function findOne(pattern) {
        const files = execSync("find node_modules/.pnpm -path '" + pattern + "'", {
          encoding: "utf8",
        })
          .trim()
          .split("\n")
          .filter(Boolean);
        if (files.length === 0) {
          throw new Error("file not found: " + pattern);
        }
        return files[0];
      }

      const collector = findOne(
        "*app-builder-lib@26.8.1*/node_modules/app-builder-lib/out/node-module-collector/traversalNodeModulesCollector.js",
      );
      patchFile(collector, [
        [
          "throw new Error(`Production dependency ''${depName} not found for package ''${moduleName}`)",
          'builder_util_1.log.warn({ parent: moduleName, dependency: depName, version }, "skipping missing production dependency")',
        ],
      ]);

      const manager = findOne(
        "*app-builder-lib@26.8.1*/node_modules/app-builder-lib/out/node-module-collector/moduleManager.js",
      );
      patchFile(manager, [
        [
          "semverSatisfies(found, range) {\n        if ((0, builder_util_1.isEmptyOrSpaces)(range) || range === \"*\") {\n            return true;\n        }",
          "semverSatisfies(found, range) {\n        return true;\n        if ((0, builder_util_1.isEmptyOrSpaces)(range) || range === \"*\") {\n            return true;\n        }",
        ],
      ]);
      EOF
    '';
  });
in
{
  home-manager.users.${vars.username} = {
    home.packages = [ airi ];
  };
}
