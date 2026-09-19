"""Apply chrome styling without managing browser history or session files."""

import configparser
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def profile_paths(root):
    registry = root / "profiles.ini"
    paths = set()
    if registry.exists():
        parser = configparser.RawConfigParser()
        parser.read(registry)
        for section in parser.sections():
            if section.startswith("Profile") and parser.has_option(section, "Path"):
                path = Path(parser.get(section, "Path"))
                if parser.getboolean(section, "IsRelative", fallback=True):
                    path = root / path
                paths.add(path)
    # Include old unregistered profiles, but never assume an arbitrary directory
    # is a profile. Registry entries support custom names and external paths.
    paths.update(root.glob("*.default*"))
    return sorted(path for path in paths if path.is_dir())


def replace_file(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() == text:
        return
    # Replace the link/file itself; an old Home Manager link may be read-only.
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as out:
        temporary = Path(out.name)
        out.write(text)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def apply_theme(root, theme, browser):
    paths = profile_paths(root)
    if not paths and not (root / "profiles.ini").exists():
        # Let the browser register its initial profile before its first GUI
        # launch. Never replace an existing registry or choose a new default.
        root.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [browser, "-headless", "-CreateProfile", f"default {root / 'themed.default'}"],
            check=True, timeout=45,
            env=os.environ | {"MOZ_HEADLESS": "1"},
        )
        paths = profile_paths(root)
    if not paths:
        raise RuntimeError(f"No usable browser profile in {root}; registry left unchanged")
    for profile in paths:
        for name in ("userChrome.css", "userContent.css"):
            replace_file(profile / "chrome" / name, (theme / name).read_text())
        prefs = profile / "user.js"
        text = prefs.read_text() if prefs.exists() else (theme / "user.js").read_text()
        enabled = 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
        pattern = r'''user_pref\(\s*["']toolkit\.legacyUserProfileCustomizations\.stylesheets["']\s*,\s*(?:true|false)\s*\);'''
        # Last setting wins even if the previous occurrence was commented out.
        text = re.sub(pattern, enabled, text)
        if not text.splitlines() or text.splitlines()[-1] != enabled:
            text = text.rstrip() + "\n" + enabled + "\n"
        replace_file(prefs, text)
    print(f"Applied browser theme to {len(paths)} profile(s)")


if __name__ == "__main__":
    apply_theme(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
