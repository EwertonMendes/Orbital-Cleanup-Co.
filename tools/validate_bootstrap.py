#!/usr/bin/env python3
"""Fast repository checks that do not require Godot."""

from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "export_presets.cfg",
    "web/shell/index.html",
    "web/platform/platform-config.js",
    "web/platform/debug-provider.js",
    "web/platform/platform-loader.js",
    "i18n/en.po",
    "i18n/pt_BR.po",
    "i18n/es_ES.po",
    "src/core/app/app_root.tscn",
    "src/core/app/app_root.gd",
    "src/core/app/scene_router.gd",
    "src/core/audio/audio_service.gd",
    "src/core/input/input_service.gd",
    "src/core/save/save_service.gd",
    "src/core/settings/settings_service.gd",
    "src/core/platform/platform_service.gd",
    "src/core/build/build_info.gd",
    "src/ui/screens/operations/operations_screen.tscn",
    "src/ui/screens/operations/operations_screen.gd",
    "src/ui/screens/flight/flight_screen.tscn",
    "src/ui/screens/flight/flight_screen.gd",
    "src/ui/utilities/responsive_canvas.gd",
    "src/game/ship/player_ship.tscn",
    "src/game/ship/player_ship.gd",
    "src/game/ship/ship_steering.gd",
    "src/game/ship/ship_movement_tuning.tres",
    "src/game/ship/ship_movement_tuning.gd",
    "src/game/ship/ship_visuals.gd",
    "src/game/ship/engine_trail.gd",
    "src/game/ship/ship_camera.gd",
    "src/game/sector/training_space.gd",
    "src/ui/screens/operations/operations_backdrop.gd",
    "src/ui/themes/occ_theme.tres",
    "src/ui/themes/occ_palette.gd",
    "tools/validate_core_contracts.gd",
    "AGENTS.md",
    "docs/ASSETS.md",
    "docs/UI_GUIDELINES.md",
]

REQUIRED_ASSETS = [
    "assets/third_party/kenney_ui_sci_fi/ui/panel_glass_notches.png",
    "assets/third_party/kenney_ui_sci_fi/ui/button_header_blade.png",
    "assets/third_party/kenney_ui_sci_fi/ui/bar_round_gloss_large.png",
    "assets/third_party/kenney_space_shooter/ships/player_ship_01_blue.png",
    "assets/third_party/kenney_space_shooter/effects/engine_speed.png",
    "assets/third_party/kenney_simple_space/scenery/station_a.png",
    "assets/third_party/kenney_simple_space/scenery/satellite_b.png",
    "assets/third_party/oxanium/Oxanium[wght].ttf",
]

PORTAL_IDENTIFIERS = ("crazygames", "gamepix", "gamemonetize", "gamedistribution", "poki")
MSGID = re.compile(r'^msgid "([^"]+)"$', re.MULTILINE)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_required_files() -> None:
    missing = [path for path in REQUIRED + REQUIRED_ASSETS if not (ROOT / path).is_file()]
    if missing:
        fail("Missing required project files: " + ", ".join(missing))


def validate_main_scene() -> None:
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'run/main_scene="res://src/core/app/app_root.tscn"' not in project:
        fail("project.godot must route through AppRoot")
    if "common/physics_interpolation=true" not in project:
        fail("2D movement builds must keep physics interpolation enabled")


def validate_translations() -> None:
    expected_languages = {
        "en.po": "Language: en",
        "pt_BR.po": "Language: pt_BR",
        "es_ES.po": "Language: es_ES",
    }
    catalogs: dict[str, set[str]] = {}
    for filename, header in expected_languages.items():
        text = (ROOT / "i18n" / filename).read_text(encoding="utf-8")
        if header not in text:
            fail(f"{filename} is missing expected language header {header!r}")
        ids = set(MSGID.findall(text))
        if not ids:
            fail(f"{filename} contains no translation messages")
        catalogs[filename] = ids

    reference = catalogs["en.po"]
    for filename, ids in catalogs.items():
        missing = sorted(reference - ids)
        extra = sorted(ids - reference)
        if missing or extra:
            fail(f"{filename} key mismatch; missing={missing}, extra={extra}")


def validate_provider_boundary() -> None:
    src_root = ROOT / "src"
    offenders: list[str] = []
    for path in src_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".tres"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        if any(identifier in text for identifier in PORTAL_IDENTIFIERS):
            offenders.append(str(path.relative_to(ROOT)))
    if offenders:
        fail("Portal SDK identifiers leaked into Godot source: " + ", ".join(offenders))

    config = (ROOT / "web/platform/platform-config.js").read_text(encoding="utf-8")
    if "__OCC_PROVIDER__" not in config:
        fail("platform-config.js must remain build-configurable")
    debug_provider = (ROOT / "web/platform/debug-provider.js").read_text(encoding="utf-8").lower()
    if "fetch(" in debug_provider or "xmlhttprequest" in debug_provider:
        fail("DebugWebProvider must not call remote ad/network APIs")


def validate_asset_provenance() -> None:
    third_party = ROOT / "assets" / "third_party"
    if not third_party.is_dir():
        fail("assets/third_party is required once third-party assets are imported")

    for source_dir in sorted(path for path in third_party.iterdir() if path.is_dir()):
        source = source_dir / "SOURCE.md"
        license_file = source_dir / "LICENSE.txt"
        if not source.is_file() or not license_file.is_file():
            fail(f"{source_dir.relative_to(ROOT)} must include SOURCE.md and LICENSE.txt")
        source_text = source.read_text(encoding="utf-8")
        if "Official source:" not in source_text or "License:" not in source_text:
            fail(f"{source.relative_to(ROOT)} must record official source and license")


def validate_visual_foundation() -> None:
    operations = (ROOT / "src" / "ui" / "screens" / "operations" / "operations_screen.tscn").read_text(encoding="utf-8")
    flight = (ROOT / "src" / "ui" / "screens" / "flight" / "flight_screen.tscn").read_text(encoding="utf-8")

    required_markers = (
        "button_header_blade.png",
        "bar_round_gloss_large.png",
        "kenney_space_shooter",
        "kenney_simple_space",
    )
    missing = [marker for marker in required_markers if marker not in operations]
    if missing:
        fail("Operations screen is missing visual foundation references: " + ", ".join(missing))

    if "panel_glass_tab_blade.png" in operations or "panel_glass_tab_blade.png" in flight:
        fail("Square Kenney tab assets must not be stretched into wide HUD/card frames")

    if 'scale = Vector2(1.15, 1.15)' in (ROOT / "src" / "game" / "ship" / "player_ship.tscn").read_text(encoding="utf-8"):
        fail("Player ship must render at native scale in gameplay")

    if "Provider:" in operations or "Build:" in operations:
        fail("Player-facing Operations UI must not expose debug/provider build metadata")

    theme = (ROOT / "src" / "ui" / "themes" / "occ_theme.tres").read_text(encoding="utf-8")
    if "Oxanium[wght].ttf" not in theme:
        fail("Shared OCC Theme must provide Oxanium typography")


def main() -> None:
    validate_required_files()
    validate_main_scene()
    validate_translations()
    validate_provider_boundary()
    validate_asset_provenance()
    validate_visual_foundation()
    print("Project validation passed.")


if __name__ == "__main__":
    main()
