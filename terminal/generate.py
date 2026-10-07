#!/usr/bin/env python3
"""Generate kitty / iTerm2 / tmux appearance files from terminal/theme.toml.

    python3 terminal/generate.py          # (re)write the generated files
    python3 terminal/generate.py --check  # exit 1 if any generated file is stale

theme.toml is the single source of truth. Unknown keys or bad values are a
hard error (never silently ignored), so a typo can't quietly drop a setting.
Only the Python standard library is used (tomllib needs Python >= 3.11).
"""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "terminal" / "theme.toml"
HEADER = "GENERATED from terminal/theme.toml by terminal/generate.py — do not edit."

KITTY_DIR = REPO / "kitty" / ".config" / "kitty"
ITERM2_PROFILE = (
    REPO / "iterm2" / "Library" / "Application Support" / "iTerm2" / "DynamicProfiles" / "dotfiles.json"
)
TMUX_THEME = REPO / "tmux" / ".tmux" / "theme.conf"

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
CURSOR_SHAPES = {"block": 2, "beam": 1, "underline": 0}  # value = iTerm2 "Cursor Type"
MODE_KEYS = (
    "background",
    "foreground",
    "cursor",
    "cursor_text",
    "selection_background",
    "selection_foreground",
)
SCHEMA = {
    "font": {"family", "postscript", "size"},
    "cursor": {"shape", "blink"},
    "window": {"opacity", "blur"},
    "tmux": {"active_pane_bg"},
    "colors": {"dark", "light", "ansi"},
    "iterm2": {"profile_name", "guid"},
}


class ThemeError(Exception):
    pass


def load() -> dict:
    with MASTER.open("rb") as f:
        t = tomllib.load(f)

    def keys(where: str, got: dict, want: set[str]) -> None:
        if extra := set(got) - want:
            raise ThemeError(f"{where}: unknown key(s) {sorted(extra)}")
        if missing := want - set(got):
            raise ThemeError(f"{where}: missing key(s) {sorted(missing)}")

    def color(where: str, v) -> None:
        if not isinstance(v, str) or not HEX.match(v):
            raise ThemeError(f"{where}: expected #rrggbb, got {v!r}")

    keys("theme.toml", t, set(SCHEMA))
    for section, want in SCHEMA.items():
        keys(f"[{section}]", t[section], want)
    for mode in ("dark", "light"):
        keys(f"[colors.{mode}]", t["colors"][mode], set(MODE_KEYS))
        for k, v in t["colors"][mode].items():
            color(f"[colors.{mode}] {k}", v)
    ansi = t["colors"]["ansi"]
    if not isinstance(ansi, list) or len(ansi) != 16:
        raise ThemeError("[colors] ansi: expected exactly 16 colors")
    for i, v in enumerate(ansi):
        color(f"[colors] ansi[{i}]", v)
    color("[tmux] active_pane_bg", t["tmux"]["active_pane_bg"])
    if t["cursor"]["shape"] not in CURSOR_SHAPES:
        raise ThemeError(f"[cursor] shape: expected one of {sorted(CURSOR_SHAPES)}")
    if not isinstance(t["cursor"]["blink"], bool):
        raise ThemeError("[cursor] blink: expected true/false")
    if not 0 < t["window"]["opacity"] <= 1:
        raise ThemeError("[window] opacity: expected 0 < opacity <= 1")
    if t["window"]["blur"] < 0 or t["font"]["size"] <= 0:
        raise ThemeError("[window] blur / [font] size: out of range")
    return t


# --- kitty -------------------------------------------------------------------


def kitty_appearance(t: dict) -> str:
    op = t["window"]["opacity"]
    lines = [
        f"# {HEADER}",
        "# Included from kitty.conf. Colors live in the *-theme.auto.conf files.",
        f"font_family      {t['font']['family']}",
        "bold_font        auto",
        "italic_font      auto",
        "bold_italic_font auto",
        f"font_size        {t['font']['size']}",
        f"cursor_shape     {t['cursor']['shape']}",
        f"cursor_blink_interval {-1 if t['cursor']['blink'] else 0}",
        f"background_opacity {op:g}",
        f"background_blur  {t['window']['blur']}",
        # tmux's explicit active-pane color would otherwise be fully opaque.
        f"transparent_background_colors {t['tmux']['active_pane_bg']}@{op:g}",
    ]
    return "\n".join(lines) + "\n"


def kitty_colors(t: dict, mode: str) -> str:
    c = t["colors"][mode]
    lines = [
        f"# {HEADER}",
        f"# kitty picks this file automatically when the OS appearance is {mode}.",
        f"background           {c['background']}",
        f"foreground           {c['foreground']}",
        f"cursor               {c['cursor']}",
        f"cursor_text_color    {c['cursor_text']}",
        f"selection_background {c['selection_background']}",
        f"selection_foreground {c['selection_foreground']}",
    ]
    lines += [f"color{i:<2}              {v}" for i, v in enumerate(t["colors"]["ansi"])]
    return "\n".join(lines) + "\n"


# --- iTerm2 ------------------------------------------------------------------


def iterm_color(hexstr: str) -> dict:
    r, g, b = (int(hexstr[i : i + 2], 16) / 255 for i in (1, 3, 5))
    return {
        "Red Component": round(r, 6),
        "Green Component": round(g, 6),
        "Blue Component": round(b, 6),
        "Alpha Component": 1,
        "Color Space": "sRGB",
    }


def iterm2_profile(t: dict) -> str:
    op = t["window"]["opacity"]
    p: dict = {
        "Name": t["iterm2"]["profile_name"],
        "Guid": t["iterm2"]["guid"],
        "Normal Font": f"{t['font']['postscript']} {t['font']['size']}",
        "Use Non-ASCII Font": False,
        "ASCII Ligatures": False,
        "Use Bold Font": True,
        "Use Italic Font": True,
        "Cursor Type": CURSOR_SHAPES[t["cursor"]["shape"]],
        "Blinking Cursor": t["cursor"]["blink"],
        "Transparency": round(1 - op, 4),
        "Only The Default BG Color Uses Transparency": False,
        "Blur": op < 1,
        "Blur Radius": t["window"]["blur"],
        "Use Separate Colors for Light and Dark Mode": True,
        # Terminal behavior (iTerm2-only keys), pinned here so the profile does
        # not depend on whatever the unmanaged default profile happens to hold.
        "Mouse Reporting": True,
        "Option Key Sends": 0,
        "Right Option Key Sends": 0,
        "Terminal Type": "xterm-256color",
    }
    names = {
        "background": "Background Color",
        "foreground": "Foreground Color",
        "cursor": "Cursor Color",
        "cursor_text": "Cursor Text Color",
        "selection_background": "Selection Color",
        "selection_foreground": "Selected Text Color",
    }
    for mode, suffix in (("light", " (Light)"), ("dark", " (Dark)")):
        c = t["colors"][mode]
        for key, name in names.items():
            p[name + suffix] = iterm_color(c[key])
        p["Bold Color" + suffix] = iterm_color(c["foreground"])
        for i, v in enumerate(t["colors"]["ansi"]):
            p[f"Ansi {i} Color{suffix}"] = iterm_color(v)
    doc = {"_comment": HEADER, "Profiles": [p]}
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


# --- tmux --------------------------------------------------------------------


def tmux_theme(t: dict) -> str:
    return f"# {HEADER}\n# Sourced from ~/.tmux.conf.\nset -g window-active-style 'bg={t['tmux']['active_pane_bg']}'\n"


# --- main --------------------------------------------------------------------


def outputs(t: dict) -> dict[Path, str]:
    return {
        KITTY_DIR / "appearance.conf": kitty_appearance(t),
        KITTY_DIR / "dark-theme.auto.conf": kitty_colors(t, "dark"),
        KITTY_DIR / "light-theme.auto.conf": kitty_colors(t, "light"),
        # macOS always reports light or dark; fall back to dark just in case.
        KITTY_DIR / "no-preference-theme.auto.conf": kitty_colors(t, "dark"),
        ITERM2_PROFILE: iterm2_profile(t),
        TMUX_THEME: tmux_theme(t),
    }


def main(argv: list[str]) -> int:
    check = argv[1:] == ["--check"]
    if argv[1:] not in ([], ["--check"]):
        print(__doc__, file=sys.stderr)
        return 2
    try:
        files = outputs(load())
    except ThemeError as e:
        print(f"terminal/theme.toml: {e}", file=sys.stderr)
        return 1

    stale = [p for p, body in files.items() if not p.exists() or p.read_text() != body]
    if check:
        for p in stale:
            print(f"stale: {p.relative_to(REPO)}", file=sys.stderr)
        if stale:
            print("run: python3 terminal/generate.py", file=sys.stderr)
        return 1 if stale else 0

    for p in stale:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body := files[p])
        print(f"wrote {p.relative_to(REPO)}")
    if not stale:
        print("up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
