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
    "web/platform/provider-utils.js",
    "web/platform/null-provider.js",
    "web/platform/debug-provider.js",
    "web/platform/crazygames-provider.js",
    "web/platform/gamepix-provider.js",
    "web/platform/gamemonetize-provider.js",
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
    "src/core/platform/ad_service.gd",
    "src/core/build/build_info.gd",
    "src/game/progression/progression_service.gd",
    "src/game/contracts/contract_session.gd",
    "src/ui/screens/operations/operations_screen.tscn",
    "src/ui/screens/operations/operations_screen.gd",
    "src/ui/components/hq_upgrade_card.gd",
    "src/ui/components/hq_upgrade_card.tscn",
    "src/ui/components/hq_rank_row.gd",
    "src/ui/components/hq_rank_row.tscn",
    "src/ui/screens/flight/flight_screen.tscn",
    "src/ui/screens/flight/flight_screen.gd",
    "src/ui/components/depot_navigation_guide.gd",
    "src/ui/screens/debrief/contract_debrief_screen.tscn",
    "src/ui/screens/debrief/contract_debrief_screen.gd",
    "src/ui/screens/debrief/debrief_celebration.gd",
    "src/ui/utilities/responsive_canvas.gd",
    "src/game/ship/player_ship.tscn",
    "src/game/ship/player_ship.gd",
    "src/game/ship/ship_steering.gd",
    "src/game/ship/ship_movement_tuning.tres",
    "src/game/ship/ship_movement_tuning.gd",
    "src/game/ship/ship_visuals.gd",
    "src/game/ship/engine_trail.gd",
    "src/game/ship/ship_camera.gd",
    "src/game/customization/ship_paint.gdshader",
    "src/game/salvage/salvage_definition.gd",
    "src/game/salvage/salvage_object.gd",
    "src/game/salvage/salvage_object.tscn",
    "src/game/salvage/cargo_hold.gd",
    "src/game/salvage/tractor_beam.gd",
    "src/game/salvage/unload_zone.gd",
    "src/game/sector/content_registry.gd",
    "src/game/sector/difficulty_scaler.gd",
    "src/game/sector/sector_generator.gd",
    "src/game/sector/sector_runtime.gd",
    "src/game/sector/sector_runtime.tscn",
    "src/game/sector/sector_obstacle.gd",
    "src/game/sector/sector_obstacle.tscn",
    "src/game/sector/sector_landmark.gd",
    "src/game/sector/sector_landmark.tscn",
    "src/game/sector/sector_backdrop.gd",
    "content/biomes/earth_orbit.json",
    "content/sectors/earth_training_01.json",
    "content/sectors/earth_training_02.json",
    "content/salvage/scrap_fragment.json",
    "content/salvage/service_scrap.json",
    "content/salvage/sensor_pod.json",
    "content/salvage/satellite_panel.json",
    "content/salvage/dense_composite.json",
    "content/salvage_tables/earth_training.json",
    "content/landmarks/service_satellite.json",
    "content/contracts/standard_cleanup.json",
    "content/contracts/full_cleanup.json",
    "content/contracts/recovery_run.json",
    "content/contracts/valuable_recovery.json",
    "content/contracts/priority_recovery.json",
    "content/modifiers/light_debris.json",
    "content/modifiers/dense_debris.json",
    "content/progression/difficulty_scaling.json",
    "content/progression/career_ranks.json",
    "content/progression/upgrades.json",
    "content/cosmetics/ship_customization.json",
    "schemas/biome.schema.json",
    "schemas/sector.schema.json",
    "schemas/salvage.schema.json",
    "schemas/landmark.schema.json",
    "schemas/contract.schema.json",
    "schemas/modifier.schema.json",
    "schemas/salvage_table.schema.json",
    "schemas/difficulty_scaling.schema.json",
    "schemas/career_ranks.schema.json",
    "schemas/upgrades.schema.json",
    "schemas/cosmetics.schema.json",
    "tools/validate_content.py",
    "src/game/visual/world_post_process.gdshader",
    "src/game/visual/world_post_process.gd",
    "src/core/performance/runtime_quality.gd",
    "src/game/visual/planet_surface.gdshader",
    "src/game/environment/environmental_field.gd",
    "src/game/environment/environment_runtime.gd",
    "assets/original/planets/earth_orbit.svg",
    "assets/original/planets/lunar_belt.svg",
    "assets/original/planets/mars_freight.svg",
    "assets/original/planets/blue_giant.svg",
    "src/game/visual/ambient_orbit_layer.gd",
    "src/game/visual/world_burst.gd",
    "src/game/visual/world_burst.tscn",
    "src/game/visual/salvage_energy.gdshader",
    "src/game/visual/procedural_sfx.gd",
    "src/game/visual/flight_feedback.gd",
    "src/ui/components/hq_discovery_card.gd",
    "src/ui/components/hq_discovery_card.tscn",
    "src/ui/components/ui_ambient_particles.gd",
    "src/ui/screens/operations/operations_scenery_motion.gd",
    "src/ui/screens/operations/operations_backdrop.gd",
    "src/ui/themes/occ_theme.tres",
    "src/ui/themes/occ_operations_theme.tres",
    "src/ui/themes/occ_cursor_skin.gd",
    "src/ui/themes/occ_palette.gd",
    "tools/validate_core_contracts.gd",
    "AGENTS.md",
    "docs/ASSETS.md",
    "docs/UI_GUIDELINES.md",
    "docs/PRODUCT_BACKLOG.md",
]

REQUIRED_ASSETS = [
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/Double/button_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/Double/button_rectangle_depth.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/Double/panel_rectangle_screws.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Blue/Double/button_square_header_blade_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Grey/Double/button_square_header_blade_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Green/Double/button_square_header_blade_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Red/Double/button_square_header_blade_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Yellow/Double/button_square_header_blade_rectangle.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_h.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_c.png",
    "assets/third_party/kenney_ui_sci_fi/ui/Extra/cursor_d.png",
    "assets/third_party/kenney_interface_sounds/audio/select_003.ogg",
    "assets/third_party/kenney_interface_sounds/audio/click_001.ogg",
    "assets/third_party/kenney_interface_sounds/audio/back_001.ogg",
    "assets/third_party/kenney_space_shooter/ships/player_ship_01_blue.png",
    "assets/third_party/kenney_space_shooter/effects/engine_speed.png",
    "assets/third_party/kenney_simple_space/scenery/station_a.png",
    "assets/third_party/kenney_simple_space/scenery/satellite_b.png",
    "assets/third_party/neuropol/NEUROPOL.ttf",
    "assets/third_party/inter/Inter[opsz,wght].ttf",
    "assets/third_party/jetbrains_mono/JetBrainsMono[wght].ttf",
    "assets/original/salvage/navigation_core.svg",
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

    loader = (ROOT / "web/platform/platform-loader.js").read_text(encoding="utf-8")
    if "OCCProviders.null" not in loader:
        fail("Unknown production providers must degrade to NullProvider, never DebugWebProvider")

    provider_expectations = {
        "crazygames-provider.js": "crazygames-sdk-v3.js",
        "gamepix-provider.js": "gamepix.sdk.js",
        "gamemonetize-provider.js": "api.gamemonetize.com/sdk.js",
    }
    for filename, marker in provider_expectations.items():
        text = (ROOT / "web" / "platform" / filename).read_text(encoding="utf-8").lower()
        if marker not in text:
            fail(f"{filename} is missing its documented provider SDK endpoint")


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
    operations_source = (ROOT / "src" / "ui" / "screens" / "operations" / "operations_screen.gd").read_text(encoding="utf-8")
    flight = (ROOT / "src" / "ui" / "screens" / "flight" / "flight_screen.tscn").read_text(encoding="utf-8")
    operations_theme = (ROOT / "src" / "ui" / "themes" / "occ_operations_theme.tres").read_text(encoding="utf-8")
    cursor_skin = (ROOT / "src" / "ui" / "themes" / "occ_cursor_skin.gd").read_text(encoding="utf-8")

    if "occ_operations_theme.tres" not in operations:
        fail("Operations must use the dedicated original Kenney UI theme")
    if "StyleBoxTexture" not in operations_theme:
        fail("Operations theme must use original Kenney textures through StyleBoxTexture")
    if "StyleBoxFlat" in operations_theme:
        fail("Operations theme must not redraw the selected Kenney kit as generic flat Godot chrome")

    required_kenney_markers = (
        "Extra/Double/button_rectangle_depth.png",
        "Extra/Double/panel_rectangle_screws.png",
        "Extra/Double/panel_glass.png",
        "Extra/Double/bar_shadow_round_outline_large.png",
        "Blue/Double/bar_round_gloss_large.png",
    )
    missing = [marker for marker in required_kenney_markers if marker not in operations_theme]
    if missing:
        fail("Operations theme is missing original Kenney UI states: " + ", ".join(missing))

    if "InterfaceParticles" in operations:
        fail("Operations console must not cover the original Kenney kit with generic teal particles")
    if "MenuWarpFX" not in operations or "menu_warp_fx.play" not in operations_source:
        fail("Operations tab changes must use the contained warp-style transition")
    if "button_square_header_blade_rectangle" in operations_theme:
        fail("Operations buttons must use neutral Kenney chrome; colored header blades are not allowed")
    if 'Button/styles/pressed = SubResource("ButtonDepth")' not in operations_theme:
        fail("Kenney buttons must keep one stable physical footprint across click states")
    if 'SecondaryButton/fonts/font = ExtResource("1")' not in operations_theme:
        fail("Interactive button labels must use the principal Neuropol game face")

    if "SettingsLayer" not in operations or "VolumeDown" not in operations or "LanguageGroup" not in operations:
        fail("Language and audio controls must live in the dedicated Settings panel")
    if "is_sector_unlocked" not in operations_source:
        fail("Operations contract browser must filter authored sectors to unlocked content")
    if "is_endless_unlocked" not in operations_source:
        fail("Endless contracts must stay hidden until actually unlocked")
    if "discovery_tab.visible = _progression.get_discovery_count() > 0" not in operations_source:
        fail("Discovery navigation must stay hidden until the player has a discovery")
    if "if not unlocked:" not in operations_source or "continue" not in operations_source:
        fail("Ship customization must not render future locked cosmetic choices")

    for marker in ("cursor_h.png", "cursor_c.png", "cursor_d.png", "Input.set_custom_mouse_cursor"):
        if marker not in cursor_skin:
            fail(f"Custom Kenney cursor contract missing: {marker}")

    if 'scale = Vector2(1.15, 1.15)' in (ROOT / "src" / "game" / "ship" / "player_ship.tscn").read_text(encoding="utf-8"):
        fail("Player ship must render at native scale in gameplay")
    if "Provider:" in operations or "Build:" in operations:
        fail("Player-facing Operations UI must not expose debug/provider build metadata")

    required_fonts = (
        "assets/third_party/neuropol/NEUROPOL.ttf",
        "assets/third_party/inter/Inter[opsz,wght].ttf",
        "assets/third_party/jetbrains_mono/JetBrainsMono[wght].ttf",
    )
    missing_fonts = [font for font in required_fonts if font not in operations_theme]
    if missing_fonts:
        fail("Operations Theme is missing professional typography families: " + ", ".join(missing_fonts))
    if "oxanium" in operations_theme.lower() or (ROOT / "assets" / "third_party" / "oxanium").exists():
        fail("Oxanium must remain removed from the project")

    if "WorldPostProcess" not in flight or "AmbientMotion" not in flight or "FlightFeedback" not in flight:
        fail("Flight scene must keep reusable post-processing, ambient motion and feedback systems")
    if "occ_operations_theme.tres" not in flight:
        fail("Live flight HUD must use the same Kenney UI design system as Operations")
    if flight.count('theme = ExtResource("4")') < 2:
        fail("Flight HUD theme must be applied directly below CanvasLayer so Kenney styles reach HudRoot controls")
    if 'theme_override_styles/panel = SubResource("MissionPanel")' in flight or 'theme_override_styles/normal = SubResource("ReturnButtonNormal")' in flight:
        fail("Live flight HUD must not retain the legacy cyan flat-panel/button overrides")


    post_shader = (ROOT / "src" / "game" / "visual" / "world_post_process.gdshader").read_text(encoding="utf-8")
    if "hint_screen_texture" not in post_shader:
        fail("World post-process must use the Godot 4 screen-texture API")


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
