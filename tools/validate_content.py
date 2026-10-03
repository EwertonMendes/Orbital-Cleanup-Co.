#!/usr/bin/env python3
"""Validate Orbital Cleanup Co. authored content without requiring Godot."""

from __future__ import annotations

from pathlib import Path
import json
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
SCHEMAS = ROOT / "schemas"

CATEGORY_DIRS = {
    "biomes": CONTENT / "biomes",
    "sectors": CONTENT / "sectors",
    "salvage": CONTENT / "salvage",
    "salvage_tables": CONTENT / "salvage_tables",
    "landmarks": CONTENT / "landmarks",
    "contracts": CONTENT / "contracts",
    "modifiers": CONTENT / "modifiers",
    "progression": CONTENT / "progression",
    "cosmetics": CONTENT / "cosmetics",
    "ships": CONTENT / "ships",
}

REQUIRED_SCHEMAS = {
    "biome.schema.json",
    "sector.schema.json",
    "salvage.schema.json",
    "landmark.schema.json",
    "contract.schema.json",
    "modifier.schema.json",
    "salvage_table.schema.json",
    "difficulty_scaling.schema.json",
    "career_ranks.schema.json",
    "upgrades.schema.json",
    "cosmetics.schema.json",
    "ship.schema.json",
    "fleet_rules.schema.json",
}

ID_RE = re.compile(r"^[a-z0-9_]+$")
HEX_COLOR_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
MSGID_RE = re.compile(r'^msgid "([^"]+)"$', re.MULTILINE)


class ValidationError(Exception):
    pass


def fail(message: str) -> None:
    raise ValidationError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
    require(isinstance(raw, dict), f"{path.relative_to(ROOT)}: root must be an object")
    return raw


def load_catalogs() -> dict[str, set[str]]:
    catalogs: dict[str, set[str]] = {}
    for filename in ("en.po", "pt_BR.po", "es_ES.po"):
        path = ROOT / "i18n" / filename
        require(path.is_file(), f"Missing localization catalog: {path.relative_to(ROOT)}")
        catalogs[filename] = set(MSGID_RE.findall(path.read_text(encoding="utf-8")))
    return catalogs


def load_category(name: str, path: Path) -> dict[str, dict[str, Any]]:
    require(path.is_dir(), f"Missing content directory: {path.relative_to(ROOT)}")
    output: dict[str, dict[str, Any]] = {}
    for file in sorted(path.glob("*.json")):
        data = load_json(file)
        item_id = data.get("id")
        require(isinstance(item_id, str) and ID_RE.fullmatch(item_id), f"{file.relative_to(ROOT)}: invalid id")
        require(file.stem == item_id, f"{file.relative_to(ROOT)}: filename must match id '{item_id}'")
        require(item_id not in output, f"Duplicate {name} id: {item_id}")
        output[item_id] = data
    require(output, f"No definitions found in {path.relative_to(ROOT)}")
    return output


def require_keys(data: dict[str, Any], keys: tuple[str, ...], label: str) -> None:
    missing = [key for key in keys if key not in data]
    require(not missing, f"{label}: missing required fields: {', '.join(missing)}")


def require_number(value: Any, label: str, minimum: float | None = None, maximum: float | None = None) -> float:
    require(isinstance(value, (int, float)) and not isinstance(value, bool), f"{label}: expected number")
    number = float(value)
    if minimum is not None:
        require(number >= minimum, f"{label}: must be >= {minimum}")
    if maximum is not None:
        require(number <= maximum, f"{label}: must be <= {maximum}")
    return number


def require_positive_weight(value: Any, label: str) -> float:
    number = require_number(value, label)
    require(number > 0.0, f"{label}: weight must be > 0")
    return number


def require_asset(path_value: Any, label: str) -> None:
    require(isinstance(path_value, str) and path_value.startswith("res://assets/"), f"{label}: asset must use res://assets/")
    disk_path = ROOT / path_value.removeprefix("res://")
    require(disk_path.is_file(), f"{label}: missing asset {path_value}")


def require_localization_key(key: Any, label: str, catalogs: dict[str, set[str]]) -> None:
    require(isinstance(key, str) and key, f"{label}: localization key is required")
    for catalog, keys in catalogs.items():
        require(key in keys, f"{label}: localization key '{key}' missing from {catalog}")


def validate_schemas() -> None:
    require(SCHEMAS.is_dir(), "Missing schemas directory")
    missing = sorted(REQUIRED_SCHEMAS - {p.name for p in SCHEMAS.glob("*.json")})
    require(not missing, "Missing schemas: " + ", ".join(missing))
    for name in REQUIRED_SCHEMAS:
        data = load_json(SCHEMAS / name)
        require(data.get("$schema") == "https://json-schema.org/draft/2020-12/schema", f"schemas/{name}: unexpected JSON Schema version")
        require(data.get("type") == "object", f"schemas/{name}: root type must be object")


def validate_salvage(items: dict[str, dict[str, Any]], catalogs: dict[str, set[str]]) -> None:
    allowed_motion = {"tumble", "drift", "heavy", "stable", "pulse", "spin"}
    allowed_effects = {"none", "spark", "scan", "pulse", "orbit"}
    sprite_paths: set[str] = set()

    for item_id, data in items.items():
        label = f"salvage/{item_id}"
        require_keys(data, (
            "display_name_key", "sprite", "category", "rarity", "base_value", "mass",
            "collect_duration", "cleanliness_value", "cargo_units", "visual_scale",
            "collision_radius", "visual_profile", "tags",
        ), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        require_asset(data["sprite"], f"{label}.sprite")
        sprite_name = Path(str(data["sprite"])).name.lower()
        require(
            "meteor" not in sprite_name,
            f"{label}.sprite: meteor silhouettes are reserved for hazards; use a recoverable-object asset",
        )
        sprite_paths.add(str(data["sprite"]))
        require(data["rarity"] in {"common", "uncommon", "rare", "epic"}, f"{label}: invalid rarity")
        require_number(data["base_value"], f"{label}.base_value", 0)
        require_number(data["mass"], f"{label}.mass", 0.01)
        require_number(data["collect_duration"], f"{label}.collect_duration", 0.01)
        require_number(data["cleanliness_value"], f"{label}.cleanliness_value", 0)
        require_number(data["cargo_units"], f"{label}.cargo_units", 1, 12)
        require_number(data["visual_scale"], f"{label}.visual_scale", 0.2, 4)
        require_number(data["collision_radius"], f"{label}.collision_radius", 6, 120)

        profile = data["visual_profile"]
        require(isinstance(profile, dict), f"{label}.visual_profile must be an object")
        expected_profile_keys = {"motion", "effect", "spin_multiplier", "float_amplitude"}
        require(set(profile) == expected_profile_keys, f"{label}.visual_profile must define exactly {sorted(expected_profile_keys)}")
        require(profile["motion"] in allowed_motion, f"{label}.visual_profile.motion is invalid")
        require(profile["effect"] in allowed_effects, f"{label}.visual_profile.effect is invalid")
        require_number(profile["spin_multiplier"], f"{label}.visual_profile.spin_multiplier", 0, 2.5)
        require_number(profile["float_amplitude"], f"{label}.visual_profile.float_amplitude", 0, 8)
        if data["rarity"] in {"rare", "epic"}:
            require(profile["effect"] != "none", f"{label}: rare/epic salvage requires a distinct visual effect")

        require(isinstance(data["tags"], list), f"{label}.tags must be an array")
        require(len(data["tags"]) == len(set(data["tags"])), f"{label}.tags contains duplicates")

    required_unique = min(20, len(items))
    require(
        len(sprite_paths) >= required_unique,
        f"Salvage art direction requires at least {required_unique} distinct silhouettes; found {len(sprite_paths)}",
    )


def validate_tables(tables: dict[str, dict[str, Any]], salvage: dict[str, dict[str, Any]]) -> None:
    for table_id, data in tables.items():
        label = f"salvage_tables/{table_id}"
        entries = data.get("entries")
        require(isinstance(entries, list) and entries, f"{label}: entries must be a non-empty array")
        seen: set[str] = set()
        total = 0.0
        for index, entry in enumerate(entries):
            require(isinstance(entry, dict), f"{label}.entries[{index}] must be an object")
            salvage_id = entry.get("salvage")
            require(salvage_id in salvage, f"{label}: Unknown salvage: {salvage_id}")
            require(salvage_id not in seen, f"{label}: duplicate salvage entry: {salvage_id}")
            seen.add(salvage_id)
            total += require_positive_weight(entry.get("weight"), f"{label}.entries[{index}].weight")
        require(total > 0.0, f"{label}: total weight must be positive")
        table_sprites = {str(salvage[salvage_id]["sprite"]) for salvage_id in seen}
        required_visuals = min(4, len(entries))
        require(
            len(table_sprites) >= required_visuals,
            f"{label}: needs at least {required_visuals} distinct salvage silhouettes; found {len(table_sprites)}",
        )


def validate_landmarks(items: dict[str, dict[str, Any]], catalogs: dict[str, set[str]]) -> None:
    for item_id, data in items.items():
        label = f"landmarks/{item_id}"
        require_keys(data, (
            "display_name_key", "sprite", "scale", "reserved_radius", "placement_radius",
            "spin_speed_range", "drift_amplitude", "ambient_effect",
        ), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        require_asset(data["sprite"], f"{label}.sprite")
        require_number(data["scale"], f"{label}.scale", 0.01)
        reserved_radius = require_number(data["reserved_radius"], f"{label}.reserved_radius", 80, 900)
        placement = data["placement_radius"]
        require(isinstance(placement, list) and len(placement) == 2, f"{label}.placement_radius must contain two values")
        low = require_number(placement[0], f"{label}.placement_radius[0]", 0)
        high = require_number(placement[1], f"{label}.placement_radius[1]", 0)
        require(low <= high, f"{label}.placement_radius min cannot exceed max")
        require(reserved_radius >= 80, f"{label}.reserved_radius must leave navigation clearance around the authored profile")
        spin = data["spin_speed_range"]
        require(isinstance(spin, list) and len(spin) == 2, f"{label}.spin_speed_range must contain two values")
        spin_low = require_number(spin[0], f"{label}.spin_speed_range[0]", -0.08, 0.08)
        spin_high = require_number(spin[1], f"{label}.spin_speed_range[1]", -0.08, 0.08)
        require(spin_low <= spin_high, f"{label}.spin_speed_range min cannot exceed max")
        require_number(data["drift_amplitude"], f"{label}.drift_amplitude", 0, 12)
        require(isinstance(data["ambient_effect"], str), f"{label}.ambient_effect must be a string")


def validate_contracts(items: dict[str, dict[str, Any]], catalogs: dict[str, set[str]]) -> None:
    allowed = {"cleanup", "full_cleanup", "recovery", "valuable_recovery", "priority_object"}
    for item_id, data in items.items():
        label = f"contracts/{item_id}"
        require_keys(data, (
            "display_name_key", "description_key", "kind", "base_pay",
            "perfect_bonus", "company_xp", "perfect_xp_bonus",
        ), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        require_localization_key(data["description_key"], label, catalogs)
        kind = data["kind"]
        require(kind in allowed, f"{label}: unsupported contract kind")

        range_key = {
            "cleanup": "target_percent_range",
            "full_cleanup": "target_percent_range",
            "recovery": "target_count_range",
            "valuable_recovery": "target_value_range",
            "priority_object": "target_count_range",
        }[kind]
        target = data.get(range_key)
        require(isinstance(target, list) and len(target) == 2, f"{label}.{range_key} must contain two values")
        maximum = 100 if range_key == "target_percent_range" else None
        low = require_number(target[0], f"{label}.{range_key}[0]", 1, maximum)
        high = require_number(target[1], f"{label}.{range_key}[1]", 1, maximum)
        require(low <= high, f"{label}.{range_key} min cannot exceed max")
        if kind == "full_cleanup":
            require(low == 100 and high == 100, f"{label}: full cleanup must target exactly 100%")

        require_number(data["base_pay"], f"{label}.base_pay", 0)
        require_number(data["perfect_bonus"], f"{label}.perfect_bonus", 0)
        require_number(data["company_xp"], f"{label}.company_xp", 0)
        require_number(data["perfect_xp_bonus"], f"{label}.perfect_xp_bonus", 0)


def validate_modifiers(items: dict[str, dict[str, Any]], catalogs: dict[str, set[str]]) -> None:
    allowed_runtime = {"salvage_count_multiplier", "obstacle_count_multiplier", "rare_weight_multiplier"}
    for item_id, data in items.items():
        label = f"modifiers/{item_id}"
        require_keys(data, ("display_name_key", "runtime"), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        runtime = data["runtime"]
        require(isinstance(runtime, dict), f"{label}.runtime must be an object")
        unknown = set(runtime) - allowed_runtime
        require(not unknown, f"{label}.runtime has unknown parameters: {', '.join(sorted(unknown))}")
        require_number(runtime.get("salvage_count_multiplier"), f"{label}.salvage_count_multiplier", 0.01)
        require_number(runtime.get("obstacle_count_multiplier"), f"{label}.obstacle_count_multiplier", 0)
        require_number(runtime.get("rare_weight_multiplier"), f"{label}.rare_weight_multiplier", 0.01)


def validate_biomes(
    items: dict[str, dict[str, Any]],
    tables: dict[str, dict[str, Any]],
    landmarks: dict[str, dict[str, Any]],
    modifiers: dict[str, dict[str, Any]],
    catalogs: dict[str, set[str]],
) -> None:
    for item_id, data in items.items():
        label = f"biomes/{item_id}"
        require_keys(data, ("display_name_key", "palette", "visual_profile", "environment", "salvage_tables", "landmarks", "modifiers", "spawn_rules", "obstacles"), label)
        require_localization_key(data["display_name_key"], label, catalogs)

        visual = data["visual_profile"]
        require(isinstance(visual, dict), f"{label}.visual_profile must be an object")
        primary_asset = visual.get("primary_asset")
        require(isinstance(primary_asset, str), f"{label}: primary asset must be a resource path")
        primary_suffix = Path(primary_asset).suffix.lower()
        require(
            primary_suffix in {".svg", ".png", ".webp"},
            f"{label}: primary asset must be an SVG, PNG, or WebP",
        )
        require((ROOT / primary_asset.removeprefix("res://")).exists(), f"{label}: Missing primary asset: {primary_asset}")
        anchor = visual.get("primary_anchor")
        require(isinstance(anchor, list) and len(anchor) == 2, f"{label}.visual_profile.primary_anchor must contain two values")
        require_number(anchor[0], f"{label}.visual_profile.primary_anchor[0]", 0, 1)
        require_number(anchor[1], f"{label}.visual_profile.primary_anchor[1]", 0, 1)
        require_number(visual.get("primary_scale"), f"{label}.visual_profile.primary_scale", 0.2, 5)
        require_number(visual.get("primary_parallax"), f"{label}.visual_profile.primary_parallax", 0, 0.5)
        require_number(visual.get("traffic_count"), f"{label}.visual_profile.traffic_count", 0, 24)
        require_number(visual.get("dust_density"), f"{label}.visual_profile.dust_density", 0, 2)
        horizon_style = visual.get("horizon_style")
        require(
            horizon_style in {"clear", "orbit", "rings", "dust", "nebula", "solar", "gas", "ice", "industrial", "anomaly"},
            f"{label}.visual_profile.horizon_style is invalid",
        )
        require_number(visual.get("horizon_intensity"), f"{label}.visual_profile.horizon_intensity", 0, 1)
        require(str(primary_asset).startswith("res://assets/original/"), f"{label}: primary asset must be project-owned")

        environment = data["environment"]
        require(isinstance(environment, dict), f"{label}.environment must be an object")
        require_number(environment.get("salvage_mass_multiplier"), f"{label}.environment.salvage_mass_multiplier", 0.5, 2)
        volumes = environment.get("volumes")
        require(isinstance(volumes, list), f"{label}.environment.volumes must be an array")
        allowed_kinds = {
            "gravity_well", "safe_corridor", "drift_current", "gas_drag", "turbulence",
            "visibility_pocket", "scanner_interference", "tractor_distortion", "magnetic_zone",
        }
        physical_motion_kinds = {
            "gravity_well", "drift_current", "gas_drag", "turbulence", "magnetic_zone",
        }
        if item_id != "earth_orbit":
            require(
                any(volume.get("kind") in physical_motion_kinds for volume in volumes if isinstance(volume, dict)),
                f"{label}: every non-baseline biome must include at least one physical ship-motion field",
            )
        for volume_index, volume in enumerate(volumes):
            field_label = f"{label}.environment.volumes[{volume_index}]"
            require(isinstance(volume, dict), f"{field_label} must be an object")
            require(volume.get("kind") in allowed_kinds, f"{field_label}: unsupported kind")
            count_range = volume.get("count_range")
            strength_range = volume.get("strength_range")
            require(isinstance(count_range, list) and len(count_range) == 2, f"{field_label}.count_range must contain two values")
            require(isinstance(strength_range, list) and len(strength_range) == 2, f"{field_label}.strength_range must contain two values")
            require(int(count_range[0]) <= int(count_range[1]), f"{field_label}.count_range min cannot exceed max")
            require(float(strength_range[0]) <= float(strength_range[1]), f"{field_label}.strength_range min cannot exceed max")
            require(volume.get("placement") in {"random", "depot"}, f"{field_label}.placement is invalid")
            require(HEX_COLOR_RE.fullmatch(str(volume.get("color", ""))) is not None, f"{field_label}.color: expected #RRGGBB")
            require(HEX_COLOR_RE.fullmatch(str(volume.get("secondary_color", ""))) is not None, f"{field_label}.secondary_color: expected #RRGGBB")
            shape = volume.get("shape")
            require(shape in {"circle", "box"}, f"{field_label}.shape is invalid")
            if shape == "circle":
                radius_range = volume.get("radius_range")
                require(isinstance(radius_range, list) and len(radius_range) == 2, f"{field_label}.radius_range must contain two values")
                radius_low = require_number(radius_range[0], f"{field_label}.radius_range[0]", 80, 2000)
                radius_high = require_number(radius_range[1], f"{field_label}.radius_range[1]", 80, 2000)
                require(radius_low <= radius_high, f"{field_label}.radius_range min cannot exceed max")
            else:
                length_range = volume.get("length_range")
                width_range = volume.get("width_range")
                require(isinstance(length_range, list) and len(length_range) == 2, f"{field_label}.length_range must contain two values")
                require(isinstance(width_range, list) and len(width_range) == 2, f"{field_label}.width_range must contain two values")
                length_low = require_number(length_range[0], f"{field_label}.length_range[0]", 200, 8000)
                length_high = require_number(length_range[1], f"{field_label}.length_range[1]", 200, 8000)
                width_low = require_number(width_range[0], f"{field_label}.width_range[0]", 100, 2000)
                width_high = require_number(width_range[1], f"{field_label}.width_range[1]", 100, 2000)
                require(length_low <= length_high, f"{field_label}.length_range min cannot exceed max")
                require(width_low <= width_high, f"{field_label}.width_range min cannot exceed max")

        palette = data["palette"]
        require(isinstance(palette, dict), f"{label}.palette must be an object")
        for key in ("background", "nebula", "accent"):
            require(HEX_COLOR_RE.fullmatch(str(palette.get(key, ""))) is not None, f"{label}.palette.{key}: expected #RRGGBB")

        for table_id in data["salvage_tables"]:
            require(table_id in tables, f"{label}: Unknown salvage table: {table_id}")
        for landmark_id in data["landmarks"]:
            require(landmark_id in landmarks, f"{label}: Unknown landmark: {landmark_id}")
        for modifier_id in data["modifiers"]:
            require(modifier_id in modifiers, f"{label}: Unknown modifier: {modifier_id}")

        rules = data["spawn_rules"]
        require(isinstance(rules, dict), f"{label}.spawn_rules must be an object")
        require_number(rules.get("min_spacing"), f"{label}.spawn_rules.min_spacing", 0)
        require_number(rules.get("edge_margin"), f"{label}.spawn_rules.edge_margin", 0)
        require_number(rules.get("starter_cluster_count"), f"{label}.spawn_rules.starter_cluster_count", 0)
        require_number(rules.get("starter_cluster_radius"), f"{label}.spawn_rules.starter_cluster_radius", 0)

        obstacles = data["obstacles"]
        require(isinstance(obstacles, list), f"{label}.obstacles must be an array")
        seen_obstacles: set[str] = set()
        for index, obstacle in enumerate(obstacles):
            require(isinstance(obstacle, dict), f"{label}.obstacles[{index}] must be an object")
            obstacle_id = obstacle.get("id")
            require(isinstance(obstacle_id, str) and obstacle_id, f"{label}.obstacles[{index}].id is required")
            require(obstacle_id not in seen_obstacles, f"{label}: duplicate obstacle id: {obstacle_id}")
            seen_obstacles.add(obstacle_id)
            require_asset(obstacle.get("sprite"), f"{label}.obstacles[{index}].sprite")
            require_positive_weight(obstacle.get("weight"), f"{label}.obstacles[{index}].weight")
            require_number(obstacle.get("texture_reference_size"), f"{label}.obstacles[{index}].texture_reference_size", 1)
            scale_min = require_number(obstacle.get("scale_min"), f"{label}.obstacles[{index}].scale_min", 0.01)
            scale_max = require_number(obstacle.get("scale_max"), f"{label}.obstacles[{index}].scale_max", 0.01)
            require(scale_min <= scale_max, f"{label}.obstacles[{index}]: scale_min cannot exceed scale_max")


def validate_sectors(
    items: dict[str, dict[str, Any]],
    biomes: dict[str, dict[str, Any]],
    tables: dict[str, dict[str, Any]],
    landmarks: dict[str, dict[str, Any]],
    contracts: dict[str, dict[str, Any]],
    modifiers: dict[str, dict[str, Any]],
    salvage: dict[str, dict[str, Any]],
    catalogs: dict[str, set[str]],
) -> None:
    for item_id, data in items.items():
        label = f"sectors/{item_id}"
        require_keys(data, ("display_name_key", "career_order", "unlock_rank", "biome", "seed", "difficulty", "map", "salvage_tables", "landmarks", "contract", "modifiers", "depot"), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        biome_id = data["biome"]
        require(biome_id in biomes, f"{label}: Unknown biome: {biome_id}")
        biome = biomes[biome_id]

        require_number(data["career_order"], f"{label}.career_order", 1)
        require(
            isinstance(data["unlock_rank"], str) and ID_RE.fullmatch(data["unlock_rank"]),
            f"{label}.unlock_rank is invalid",
        )
        require_number(data["seed"], f"{label}.seed", 0)
        require_number(data["difficulty"], f"{label}.difficulty", 1)

        map_data = data["map"]
        require(isinstance(map_data, dict), f"{label}.map must be an object")
        half = map_data.get("half_extents")
        require(isinstance(half, list) and len(half) == 2, f"{label}.map.half_extents must contain two values")
        require_number(half[0], f"{label}.map.half_extents[0]", 600)
        require_number(half[1], f"{label}.map.half_extents[1]", 400)
        require_number(map_data.get("debris_density"), f"{label}.map.debris_density", 0.1, 3)
        require_number(map_data.get("cluster_count"), f"{label}.map.cluster_count", 1)

        table_refs = data["salvage_tables"]
        require(isinstance(table_refs, list) and table_refs, f"{label}.salvage_tables must be non-empty")
        for index, table_ref in enumerate(table_refs):
            require(isinstance(table_ref, dict), f"{label}.salvage_tables[{index}] must be an object")
            table_id = table_ref.get("id")
            require(table_id in tables, f"{label}: Unknown salvage table: {table_id}")
            require(table_id in biome["salvage_tables"], f"{label}: salvage table '{table_id}' is not allowed by biome '{biome_id}'")
            require_positive_weight(table_ref.get("weight"), f"{label}.salvage_tables[{index}].weight")

        landmark_ids = data["landmarks"]
        require(isinstance(landmark_ids, list) and len(landmark_ids) <= 2, f"{label}.landmarks supports at most two entries")
        require(len(landmark_ids) == len(set(landmark_ids)), f"{label}.landmarks contains duplicates")
        for landmark_id in landmark_ids:
            require(landmark_id in landmarks, f"{label}: Unknown landmark: {landmark_id}")
            require(landmark_id in biome["landmarks"], f"{label}: landmark '{landmark_id}' is not allowed by biome '{biome_id}'")

        modifier_ids = data["modifiers"]
        require(isinstance(modifier_ids, list), f"{label}.modifiers must be an array")
        require(len(modifier_ids) == len(set(modifier_ids)), f"{label}.modifiers contains duplicates")
        for modifier_id in modifier_ids:
            require(modifier_id in modifiers, f"{label}: Unknown modifier: {modifier_id}")
            require(modifier_id in biome["modifiers"], f"{label}: modifier '{modifier_id}' is not allowed by biome '{biome_id}'")

        contract = data["contract"]
        require(isinstance(contract, dict), f"{label}.contract must be an object")
        contract_id = contract.get("type")
        require(contract_id in contracts, f"{label}: Unknown contract: {contract_id}")
        definition = contracts[contract_id]
        kind = definition["kind"]

        expected_fields = {"type"}
        if kind in {"cleanup", "full_cleanup"}:
            expected_fields.add("target_percent")
            target = require_number(contract.get("target_percent"), f"{label}.contract.target_percent", 1, 100)
            allowed_range = definition["target_percent_range"]
            require(float(allowed_range[0]) <= target <= float(allowed_range[1]), f"{label}: target_percent outside contract range")
        elif kind == "recovery":
            expected_fields.add("target_count")
            target = require_number(contract.get("target_count"), f"{label}.contract.target_count", 1)
            allowed_range = definition["target_count_range"]
            require(float(allowed_range[0]) <= target <= float(allowed_range[1]), f"{label}: target_count outside contract range")
        elif kind == "valuable_recovery":
            expected_fields.add("target_value")
            target = require_number(contract.get("target_value"), f"{label}.contract.target_value", 1)
            allowed_range = definition["target_value_range"]
            require(float(allowed_range[0]) <= target <= float(allowed_range[1]), f"{label}: target_value outside contract range")
        elif kind == "priority_object":
            expected_fields.update({"target_count", "target_salvage_id"})
            target = require_number(contract.get("target_count"), f"{label}.contract.target_count", 1)
            allowed_range = definition["target_count_range"]
            require(float(allowed_range[0]) <= target <= float(allowed_range[1]), f"{label}: target_count outside contract range")
            target_salvage_id = contract.get("target_salvage_id")
            require(target_salvage_id in salvage, f"{label}: Unknown priority salvage: {target_salvage_id}")
            allowed_salvage = {
                str(entry["salvage"])
                for table_ref in table_refs
                for entry in tables[str(table_ref["id"])]["entries"]
            }
            require(
                target_salvage_id in allowed_salvage,
                f"{label}: priority salvage '{target_salvage_id}' must exist in one of the sector salvage tables",
            )

        require(set(contract) == expected_fields, f"{label}.contract fields must be exactly {sorted(expected_fields)} for kind '{kind}'")

        depot = data["depot"]
        require(isinstance(depot, dict), f"{label}.depot must be an object")
        position = depot.get("position")
        require(isinstance(position, list) and len(position) == 2, f"{label}.depot.position must contain two values")
        require_number(position[0], f"{label}.depot.position[0]")
        require_number(position[1], f"{label}.depot.position[1]")


def validate_difficulty(data: dict[str, Any]) -> None:
    label = "progression/difficulty_scaling"
    curves = data.get("curves")
    require(isinstance(curves, dict), f"{label}.curves must be an object")
    required = {"salvage_count", "obstacle_count", "rare_weight_multiplier", "mass_multiplier", "reward_multiplier"}
    require(required <= set(curves), f"{label}: missing curves: {', '.join(sorted(required - set(curves)))}")
    for curve_id in required:
        curve = curves[curve_id]
        require(isinstance(curve, dict), f"{label}.{curve_id} must be an object")
        base = require_number(curve.get("base"), f"{label}.{curve_id}.base")
        require_number(curve.get("per_level"), f"{label}.{curve_id}.per_level", 0)
        maximum = require_number(curve.get("max"), f"{label}.{curve_id}.max")
        require(maximum >= base, f"{label}.{curve_id}.max cannot be below base")



def validate_career_ranks(data: dict[str, Any], catalogs: dict[str, set[str]]) -> None:
    label = "progression/career_ranks"
    ranks = data.get("ranks")
    require(isinstance(ranks, list) and ranks, f"{label}.ranks must be a non-empty array")
    seen: set[str] = set()
    previous_xp = -1
    for index, rank in enumerate(ranks):
        require(isinstance(rank, dict), f"{label}.ranks[{index}] must be an object")
        rank_id = rank.get("id")
        require(isinstance(rank_id, str) and ID_RE.fullmatch(rank_id), f"{label}.ranks[{index}].id is invalid")
        require(rank_id not in seen, f"{label}: duplicate rank id: {rank_id}")
        seen.add(rank_id)
        require_localization_key(rank.get("display_name_key"), f"{label}.{rank_id}", catalogs)
        min_xp = int(require_number(rank.get("min_xp"), f"{label}.{rank_id}.min_xp", 0))
        require(min_xp > previous_xp, f"{label}: rank XP thresholds must be strictly increasing")
        previous_xp = min_xp
    require(int(ranks[0]["min_xp"]) == 0, f"{label}: first rank must start at 0 XP")
    endless_rank = data.get("endless_unlock_rank")
    require(endless_rank in seen, f"{label}.endless_unlock_rank: Unknown rank: {endless_rank}")


def validate_sector_progression(
    sectors: dict[str, dict[str, Any]],
    ranks_data: dict[str, Any],
) -> None:
    label = "sector progression"
    ranks = ranks_data.get("ranks", [])
    rank_ids = [str(rank["id"]) for rank in ranks]
    rank_index = {rank_id: index for index, rank_id in enumerate(rank_ids)}

    ordered = sorted(sectors.values(), key=lambda sector: int(sector["career_order"]))
    orders = [int(sector["career_order"]) for sector in ordered]
    require(len(orders) == len(set(orders)), f"{label}: career_order values must be unique")
    require(
        orders == list(range(1, len(ordered) + 1)),
        f"{label}: career_order must be contiguous from 1",
    )

    previous_rank_index = -1
    for sector in ordered:
        sector_id = str(sector["id"])
        unlock_rank = str(sector["unlock_rank"])
        require(
            unlock_rank in rank_index,
            f"{label}/{sector_id}: Unknown unlock rank: {unlock_rank}",
        )
        current_index = rank_index[unlock_rank]
        require(
            current_index >= previous_rank_index,
            f"{label}/{sector_id}: unlock ranks cannot move backwards in career order",
        )
        previous_rank_index = current_index

    endless_rank = ranks_data.get("endless_unlock_rank")
    require(
        endless_rank in rank_index,
        f"{label}: Unknown Endless unlock rank: {endless_rank}",
    )


def validate_upgrades(data: dict[str, Any], catalogs: dict[str, set[str]]) -> None:
    label = "progression/upgrades"
    base_ship = data.get("base_ship")
    require(isinstance(base_ship, dict), f"{label}.base_ship must be an object")
    allowed_base = {
        "scan_range",
        "collection_speed_multiplier",
        "cargo_capacity",
        "boost_recharge_rate",
        "boost_duration_bonus",
        "boost_charge_capacity",
    }
    require(set(base_ship) == allowed_base, f"{label}.base_ship must define exactly {sorted(allowed_base)}")
    for key, value in base_ship.items():
        minimum = 0.0 if key == "boost_duration_bonus" else 0.01
        require_number(value, f"{label}.base_ship.{key}", minimum)

    upgrades = data.get("upgrades")
    require(isinstance(upgrades, list) and len(upgrades) >= 3, f"{label}.upgrades must contain at least three upgrades")
    seen: set[str] = set()
    allowed_effects = {
        "scan_range_add",
        "collection_speed_multiplier_add",
        "cargo_capacity_add",
        "boost_recharge_rate_add",
        "boost_duration_bonus_add",
        "boost_charge_capacity_add",
    }
    for index, upgrade in enumerate(upgrades):
        require(isinstance(upgrade, dict), f"{label}.upgrades[{index}] must be an object")
        upgrade_id = upgrade.get("id")
        require(isinstance(upgrade_id, str) and ID_RE.fullmatch(upgrade_id), f"{label}.upgrades[{index}].id is invalid")
        require(upgrade_id not in seen, f"{label}: duplicate upgrade id: {upgrade_id}")
        seen.add(upgrade_id)
        require_localization_key(upgrade.get("display_name_key"), f"{label}.{upgrade_id}", catalogs)
        require_localization_key(upgrade.get("description_key"), f"{label}.{upgrade_id}", catalogs)
        require_number(upgrade.get("max_level"), f"{label}.{upgrade_id}.max_level", 1)
        require_number(upgrade.get("base_cost"), f"{label}.{upgrade_id}.base_cost", 1)
        require_number(upgrade.get("cost_multiplier"), f"{label}.{upgrade_id}.cost_multiplier", 1)
        effects = upgrade.get("effects")
        require(isinstance(effects, dict) and effects, f"{label}.{upgrade_id}.effects must be non-empty")
        unknown = set(effects) - allowed_effects
        require(not unknown, f"{label}.{upgrade_id}: unknown effects: {', '.join(sorted(unknown))}")
        for effect_id, amount in effects.items():
            require_number(amount, f"{label}.{upgrade_id}.effects.{effect_id}", 0.0001)


def validate_fleet_rules(
    data: dict[str, Any],
    ranks_data: dict[str, Any],
    catalogs: dict[str, set[str]],
) -> None:
    label = "progression/fleet_rules"
    require(data.get("id") == "fleet_rules", f"{label}.id must be fleet_rules")
    default_ship_id = data.get("default_ship_id")
    require(isinstance(default_ship_id, str) and ID_RE.fullmatch(default_ship_id), f"{label}.default_ship_id is invalid")

    mastery = data.get("mastery")
    require(isinstance(mastery, dict), f"{label}.mastery must be an object")
    require_number(mastery.get("contract_xp"), f"{label}.mastery.contract_xp", 0)
    require_number(mastery.get("perfect_cleanup_bonus"), f"{label}.mastery.perfect_cleanup_bonus", 0)
    levels = mastery.get("levels")
    require(isinstance(levels, list) and len(levels) >= 2, f"{label}.mastery.levels must contain at least two thresholds")
    previous = -1
    for index, value in enumerate(levels):
        require(isinstance(value, int) and value >= 0, f"{label}.mastery.levels[{index}] must be a non-negative integer")
        require(value > previous, f"{label}.mastery.levels must be strictly increasing")
        previous = value

    rank_ids = {str(rank["id"]) for rank in ranks_data.get("ranks", [])}
    tracks = data.get("upgrade_tracks")
    require(isinstance(tracks, list) and len(tracks) == 5, f"{label}.upgrade_tracks must define exactly five permanent systems")
    track_ids: set[str] = set()
    for index, track in enumerate(tracks):
        require(isinstance(track, dict), f"{label}.upgrade_tracks[{index}] must be an object")
        track_id = track.get("id")
        require(isinstance(track_id, str) and ID_RE.fullmatch(track_id), f"{label}.upgrade_tracks[{index}].id is invalid")
        require(track_id not in track_ids, f"{label}: duplicate upgrade track {track_id}")
        track_ids.add(track_id)
        require_localization_key(track.get("display_name_key"), f"{label}.{track_id}", catalogs)
        require_localization_key(track.get("description_key"), f"{label}.{track_id}", catalogs)
        require_number(track.get("max_level"), f"{label}.{track_id}.max_level", 1)
        require_number(track.get("base_cost"), f"{label}.{track_id}.base_cost", 1)
        require_number(track.get("cost_multiplier"), f"{label}.{track_id}.cost_multiplier", 1)
        effects = track.get("effects")
        require(isinstance(effects, dict) and effects, f"{label}.{track_id}.effects must be non-empty")
        for effect_id, amount in effects.items():
            require(effect_id.endswith("_add"), f"{label}.{track_id}: unsupported effect semantic {effect_id}")
            require(isinstance(amount, (int, float)) and not isinstance(amount, bool), f"{label}.{track_id}.{effect_id} must be numeric")
        for milestone_index, milestone in enumerate(track.get("milestones", [])):
            require(isinstance(milestone, dict), f"{label}.{track_id}.milestones[{milestone_index}] must be an object")
            level = milestone.get("level")
            require(isinstance(level, int) and 1 <= level <= int(track["max_level"]), f"{label}.{track_id}.milestones[{milestone_index}].level is invalid")
            milestone_effects = milestone.get("effects")
            require(isinstance(milestone_effects, dict) and milestone_effects, f"{label}.{track_id}.milestones[{milestone_index}].effects required")

    modules = data.get("modules")
    require(isinstance(modules, list) and len(modules) >= 4, f"{label}.modules must contain starter modules")
    module_ids: set[str] = set()
    for index, module in enumerate(modules):
        require(isinstance(module, dict), f"{label}.modules[{index}] must be an object")
        module_id = module.get("id")
        require(isinstance(module_id, str) and ID_RE.fullmatch(module_id), f"{label}.modules[{index}].id is invalid")
        require(module_id not in module_ids, f"{label}: duplicate module {module_id}")
        module_ids.add(module_id)
        require(module.get("slot") in {"propulsion", "recovery", "cargo", "utility"}, f"{label}.{module_id}: invalid slot")
        require_localization_key(module.get("display_name_key"), f"{label}.{module_id}", catalogs)
        require_localization_key(module.get("description_key"), f"{label}.{module_id}", catalogs)
        require(module.get("unlock_rank") in rank_ids, f"{label}.{module_id}: unknown unlock rank")
        require_number(module.get("price"), f"{label}.{module_id}.price", 0)
        effects = module.get("effects")
        require(isinstance(effects, dict), f"{label}.{module_id}.effects must be an object")
        for effect_id, amount in effects.items():
            require(effect_id.endswith("_add"), f"{label}.{module_id}: unsupported effect semantic {effect_id}")
            require(isinstance(amount, (int, float)) and not isinstance(amount, bool), f"{label}.{module_id}.{effect_id} must be numeric")


def validate_ships(
    ships: dict[str, dict[str, Any]],
    fleet_rules: dict[str, Any],
    ranks_data: dict[str, Any],
    catalogs: dict[str, set[str]],
) -> None:
    label = "ships"
    require(ships, f"{label}: at least one ship definition is required")
    rank_ids = {str(rank["id"]) for rank in ranks_data.get("ranks", [])}
    modules = {str(item["id"]): item for item in fleet_rules.get("modules", [])}
    default_ship_id = str(fleet_rules.get("default_ship_id", ""))
    require(default_ship_id in ships, f"{label}: default ship {default_ship_id} is missing")

    required_stats = {
        "max_speed", "acceleration", "dry_mass", "cargo_inertia_factor", "turn_response",
        "boost_acceleration", "boost_duration", "boost_recharge_seconds", "boost_turn_authority",
        "scan_range", "capture_distance", "pull_speed", "collection_speed_multiplier",
        "cargo_capacity", "boost_recharge_rate", "boost_duration_bonus", "boost_charge_capacity",
        "environment_force_response", "environment_drag_response",
    }
    for ship_id, ship in ships.items():
        ship_label = f"{label}/{ship_id}"
        require_localization_key(ship.get("display_name_key"), ship_label, catalogs)
        require_localization_key(ship.get("description_key"), ship_label, catalogs)
        require_localization_key(ship.get("role_key"), ship_label, catalogs)

        unlock = ship.get("unlock")
        require(isinstance(unlock, dict), f"{ship_label}.unlock must be an object")
        require(unlock.get("rank") in rank_ids, f"{ship_label}.unlock.rank is unknown")
        require_number(unlock.get("price"), f"{ship_label}.unlock.price", 0)

        stats = ship.get("base_stats")
        require(isinstance(stats, dict), f"{ship_label}.base_stats must be an object")
        require(set(stats) == required_stats, f"{ship_label}.base_stats must define exactly {sorted(required_stats)}")
        for stat_id, value in stats.items():
            minimum = 0 if stat_id == "boost_duration_bonus" else 0.0001
            require_number(value, f"{ship_label}.base_stats.{stat_id}", minimum)

        slots = ship.get("module_slots")
        defaults = ship.get("default_modules")
        require(isinstance(slots, dict) and isinstance(defaults, dict), f"{ship_label}: module slots/defaults required")
        require(set(slots) == {"propulsion", "recovery", "cargo", "utility"}, f"{ship_label}: invalid module slot set")
        require(set(defaults) == set(slots), f"{ship_label}: every slot requires a default module")
        for slot, module_ids in defaults.items():
            require(isinstance(module_ids, list), f"{ship_label}: default modules for {slot} must be an array")
            require(len(module_ids) == int(slots[slot]), f"{ship_label}: {slot} defaults must match authored slot count")
            for module_id in module_ids:
                require(module_id in modules, f"{ship_label}: unknown default module {module_id}")
                require(str(modules[module_id]["slot"]) == slot, f"{ship_label}: default module {module_id} does not match {slot}")

        visual = ship.get("visual")
        require(isinstance(visual, dict), f"{ship_label}.visual must be an object")
        require_asset(visual.get("base_texture"), f"{ship_label}.visual.base_texture")
        require_number(visual.get("render_scale"), f"{ship_label}.visual.render_scale", 0.001)
        require(visual.get("paint_mode") in {"legacy_blue_bias", "rgb_mask"}, f"{ship_label}.visual.paint_mode is invalid")
        mask_path = str(visual.get("paint_mask", ""))
        if visual.get("paint_mode") == "rgb_mask":
            require(mask_path, f"{ship_label}: rgb_mask paint mode requires paint_mask")
            require_asset(mask_path, f"{ship_label}.visual.paint_mask")
        for optional_asset in ("details_texture", "emissive_texture"):
            path = str(visual.get(optional_asset, ""))
            if path:
                require_asset(path, f"{ship_label}.visual.{optional_asset}")
        sockets = visual.get("engine_sockets")
        require(isinstance(sockets, list) and sockets, f"{ship_label}: at least one engine socket is required")
        for socket_index, socket in enumerate(sockets):
            require(isinstance(socket, dict), f"{ship_label}.engine_sockets[{socket_index}] must be an object")
            position = socket.get("position")
            require(isinstance(position, list) and len(position) == 2, f"{ship_label}.engine_sockets[{socket_index}].position must have two values")
            require(all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in position), f"{ship_label}.engine_sockets[{socket_index}].position must be numeric")
            if "fx_scale" in socket:
                require_number(socket["fx_scale"], f"{ship_label}.engine_sockets[{socket_index}].fx_scale", 0.25, 2.5)
            if "rotation_degrees" in socket:
                require_number(socket["rotation_degrees"], f"{ship_label}.engine_sockets[{socket_index}].rotation_degrees", -180, 180)
        tractor_socket = visual.get("tractor_socket")
        require(isinstance(tractor_socket, list) and len(tractor_socket) == 2, f"{ship_label}.tractor_socket must have two values")
        require(visual.get("collision_mode") == "base_alpha", f"{ship_label}: collision must come from the base model only")


def validate_cosmetics(
    data: dict[str, Any],
    ranks_data: dict[str, Any],
    catalogs: dict[str, set[str]],
) -> None:
    label = "cosmetics/ship_customization"
    categories = data.get("categories")
    defaults = data.get("default_loadout")
    require(isinstance(categories, dict), f"{label}.categories must be an object")
    require(isinstance(defaults, dict), f"{label}.default_loadout must be an object")

    expected_categories = {"paint", "livery", "decal", "canopy", "body_kit", "engine", "trail", "beam"}
    require(set(categories) == expected_categories, f"{label}.categories must define exactly {sorted(expected_categories)}")
    require(set(defaults) == expected_categories, f"{label}.default_loadout must define exactly {sorted(expected_categories)}")

    rank_ids = {str(rank["id"]) for rank in ranks_data.get("ranks", [])}
    require(rank_ids, f"{label}: career ranks are required")

    option_ids: dict[str, set[str]] = {}
    option_ranks: dict[str, dict[str, str]] = {}

    for category in sorted(expected_categories):
        options = categories.get(category)
        require(isinstance(options, list) and options, f"{label}.{category} must be a non-empty array")
        seen: set[str] = set()
        ranks_by_id: dict[str, str] = {}

        for index, option in enumerate(options):
            require(isinstance(option, dict), f"{label}.{category}[{index}] must be an object")
            option_id = option.get("id")
            require(isinstance(option_id, str) and ID_RE.fullmatch(option_id), f"{label}.{category}[{index}].id is invalid")
            require(option_id not in seen, f"{label}.{category}: duplicate id: {option_id}")
            seen.add(option_id)
            require_localization_key(option.get("display_name_key"), f"{label}.{category}.{option_id}", catalogs)
            unlock_rank = option.get("unlock_rank")
            require(unlock_rank in rank_ids, f"{label}.{category}.{option_id}: Unknown rank: {unlock_rank}")
            require_number(option.get("price"), f"{label}.{category}.{option_id}.price", 0)
            ranks_by_id[option_id] = str(unlock_rank)

            if category == "paint":
                for color_key in ("color", "secondary_color", "accent_color"):
                    require(HEX_COLOR_RE.fullmatch(str(option.get(color_key, ""))) is not None, f"{label}.{category}.{option_id}.{color_key}: expected #RRGGBB")
                require_number(option.get("strength"), f"{label}.{category}.{option_id}.strength", 0, 1)
            elif category in {"livery", "decal", "body_kit"}:
                path = str(option.get("texture", ""))
                if path:
                    require_asset(path, f"{label}.{category}.{option_id}.texture")
            elif category == "canopy":
                require(HEX_COLOR_RE.fullmatch(str(option.get("color", ""))) is not None, f"{label}.{category}.{option_id}.color: expected #RRGGBB")
                path = str(option.get("texture", ""))
                if path:
                    require_asset(path, f"{label}.{category}.{option_id}.texture")
            elif category == "engine":
                trail_profile = option.get("trail")
                require(isinstance(trail_profile, dict), f"{label}.{category}.{option_id}.trail must be an object")
                expected_trail_fields = {
                    "mode", "width", "lifetime", "sample_interval", "minimum_sample_distance",
                    "max_samples", "opacity", "preview_length", "preview_points",
                    "boost_width_bonus", "boost_lifetime_bonus", "strand_count",
                    "strand_spread", "strand_width_decay", "strand_alpha_decay",
                    "wave_amplitude", "wave_frequency", "animation_speed",
                    "pulse_count", "jitter_amplitude", "angularity",
                }
                require(
                    set(trail_profile) == expected_trail_fields,
                    f"{label}.{category}.{option_id}.trail must define exactly {sorted(expected_trail_fields)}",
                )
                mode = str(trail_profile.get("mode", ""))
                require(
                    mode in {"ribbon", "plasma", "pulse", "spark", "comet", "shard", "mist", "dual_helix", "prism_fan", "phase_rails", "gravity_bow", "vortex_coil", "vector_cascade"},
                    f"{label}.{category}.{option_id}.trail.mode is invalid",
                )
                require_number(trail_profile.get("width"), f"{label}.{category}.{option_id}.trail.width", 0.75, 72)
                require_number(trail_profile.get("lifetime"), f"{label}.{category}.{option_id}.trail.lifetime", 0.1, 2.0)
                require_number(trail_profile.get("sample_interval"), f"{label}.{category}.{option_id}.trail.sample_interval", 0.005, 0.2)
                require_number(trail_profile.get("minimum_sample_distance"), f"{label}.{category}.{option_id}.trail.minimum_sample_distance", 0.1, 20)
                require_number(trail_profile.get("max_samples"), f"{label}.{category}.{option_id}.trail.max_samples", 8, 120)
                require_number(trail_profile.get("opacity"), f"{label}.{category}.{option_id}.trail.opacity", 0.05, 1)
                require_number(trail_profile.get("preview_length"), f"{label}.{category}.{option_id}.trail.preview_length", 12, 520)
                require_number(trail_profile.get("preview_points"), f"{label}.{category}.{option_id}.trail.preview_points", 8, 64)
                require_number(trail_profile.get("boost_width_bonus"), f"{label}.{category}.{option_id}.trail.boost_width_bonus", 0, 1)
                require_number(trail_profile.get("boost_lifetime_bonus"), f"{label}.{category}.{option_id}.trail.boost_lifetime_bonus", 0, 1)
                require_number(trail_profile.get("strand_count"), f"{label}.{category}.{option_id}.trail.strand_count", 1, 3)
                require_number(trail_profile.get("strand_spread"), f"{label}.{category}.{option_id}.trail.strand_spread", 0, 24)
                require_number(trail_profile.get("strand_width_decay"), f"{label}.{category}.{option_id}.trail.strand_width_decay", 0.1, 1)
                require_number(trail_profile.get("strand_alpha_decay"), f"{label}.{category}.{option_id}.trail.strand_alpha_decay", 0.1, 1)
                require_number(trail_profile.get("wave_amplitude"), f"{label}.{category}.{option_id}.trail.wave_amplitude", 0, 24)
                require_number(trail_profile.get("wave_frequency"), f"{label}.{category}.{option_id}.trail.wave_frequency", 0, 10)
                require_number(trail_profile.get("animation_speed"), f"{label}.{category}.{option_id}.trail.animation_speed", 0, 16)
                require_number(trail_profile.get("pulse_count"), f"{label}.{category}.{option_id}.trail.pulse_count", 0, 10)
                require_number(trail_profile.get("jitter_amplitude"), f"{label}.{category}.{option_id}.trail.jitter_amplitude", 0, 24)
                require_number(trail_profile.get("angularity"), f"{label}.{category}.{option_id}.trail.angularity", 0, 1)

                if mode == "ribbon":
                    require(float(trail_profile["wave_amplitude"]) == 0 and float(trail_profile["jitter_amplitude"]) == 0, f"{label}.{category}.{option_id}: ribbon must stay clean and stable")
                elif mode == "plasma":
                    require(int(trail_profile["strand_count"]) >= 3 and float(trail_profile["wave_amplitude"]) >= 4, f"{label}.{category}.{option_id}: plasma must use a multi-strand wave")
                elif mode == "pulse":
                    require(int(trail_profile["pulse_count"]) >= 4, f"{label}.{category}.{option_id}: pulse style must expose visible repeated pulses")
                elif mode == "spark":
                    require(int(trail_profile["strand_count"]) >= 3 and float(trail_profile["jitter_amplitude"]) >= 4, f"{label}.{category}.{option_id}: spark style must use multiple broken jitter strands")
                elif mode == "comet":
                    require(float(trail_profile["lifetime"]) >= 0.9 and float(trail_profile["preview_length"]) >= 120, f"{label}.{category}.{option_id}: comet style must remain intentionally long")
                elif mode == "shard":
                    require(float(trail_profile["angularity"]) >= 0.8 and float(trail_profile["jitter_amplitude"]) >= 3, f"{label}.{category}.{option_id}: shard style must remain angular")
                elif mode == "mist":
                    require(int(trail_profile["strand_count"]) >= 3 and float(trail_profile["opacity"]) <= 0.6, f"{label}.{category}.{option_id}: mist style must use diffuse multi-strands")
                elif mode == "dual_helix":
                    require(int(trail_profile["strand_count"]) == 2 and float(trail_profile["wave_amplitude"]) >= 6, f"{label}.{category}.{option_id}: twin helix must use two clearly separated strands")
                elif mode == "prism_fan":
                    require(int(trail_profile["strand_count"]) == 3 and float(trail_profile["strand_spread"]) >= 10, f"{label}.{category}.{option_id}: prism fan must open three clearly separated rays")
                elif mode == "phase_rails":
                    require(int(trail_profile["strand_count"]) == 2 and float(trail_profile["wave_amplitude"]) >= 6 and float(trail_profile["wave_frequency"]) >= 3, f"{label}.{category}.{option_id}: phase rails must visibly switch between two lanes")
                elif mode == "gravity_bow":
                    require(int(trail_profile["strand_count"]) == 2 and float(trail_profile["strand_spread"]) >= 8 and float(trail_profile["wave_amplitude"]) >= 4, f"{label}.{category}.{option_id}: gravity bow must form two wide mirrored arcs")
                elif mode == "vortex_coil":
                    require(int(trail_profile["strand_count"]) == 3 and float(trail_profile["wave_amplitude"]) >= 6 and float(trail_profile["wave_frequency"]) >= 3, f"{label}.{category}.{option_id}: vortex coil must use a widening three-strand chirp")
                elif mode == "vector_cascade":
                    require(int(trail_profile["strand_count"]) == 3 and int(trail_profile["pulse_count"]) >= 4 and float(trail_profile["wave_amplitude"]) >= 5, f"{label}.{category}.{option_id}: vector cascade must use quantized multi-strand steps")
            elif category == "trail":
                palette = option.get("palette")
                require(isinstance(palette, dict), f"{label}.{category}.{option_id}.palette must be an object")
                expected_palette = {"trail_tail", "trail_mid", "trail_head", "accent"}
                require(set(palette) == expected_palette, f"{label}.{category}.{option_id}.palette must define exactly {sorted(expected_palette)}")
                for color_key in sorted(expected_palette):
                    require(
                        HEX_COLOR_RE.fullmatch(str(palette.get(color_key, ""))) is not None,
                        f"{label}.{category}.{option_id}.palette.{color_key}: expected #RRGGBB",
                    )
            elif category == "beam":
                for color_key in ("glow_color", "core_color"):
                    require(HEX_COLOR_RE.fullmatch(str(option.get(color_key, ""))) is not None, f"{label}.{category}.{option_id}.{color_key}: expected #RRGGBB")
                require_number(option.get("glow_width"), f"{label}.{category}.{option_id}.glow_width", 2, 20)
                require_number(option.get("core_width"), f"{label}.{category}.{option_id}.core_width", 0.5, 8)
                require_number(option.get("pulse_width"), f"{label}.{category}.{option_id}.pulse_width", 0, 6)
                require_number(option.get("pulse_speed"), f"{label}.{category}.{option_id}.pulse_speed", 1, 30)

        option_ids[category] = seen
        option_ranks[category] = ranks_by_id

    trainee_rank = str(ranks_data["ranks"][0]["id"])
    for category in sorted(expected_categories):
        default_id = defaults.get(category)
        require(default_id in option_ids[category], f"{label}: default {category} references unknown option: {default_id}")
        require(
            option_ranks[category][str(default_id)] == trainee_rank,
            f"{label}: default {category} must unlock at the starting rank",
        )


def main() -> None:
    try:
        validate_schemas()
        catalogs = load_catalogs()
        loaded = {name: load_category(name, path) for name, path in CATEGORY_DIRS.items()}

        validate_salvage(loaded["salvage"], catalogs)
        validate_tables(loaded["salvage_tables"], loaded["salvage"])
        validate_landmarks(loaded["landmarks"], catalogs)
        validate_contracts(loaded["contracts"], catalogs)
        validate_modifiers(loaded["modifiers"], catalogs)
        validate_biomes(
            loaded["biomes"],
            loaded["salvage_tables"],
            loaded["landmarks"],
            loaded["modifiers"],
            catalogs,
        )
        validate_sectors(
            loaded["sectors"],
            loaded["biomes"],
            loaded["salvage_tables"],
            loaded["landmarks"],
            loaded["contracts"],
            loaded["modifiers"],
            loaded["salvage"],
            catalogs,
        )
        require("difficulty_scaling" in loaded["progression"], "Missing progression/difficulty_scaling.json")
        require("career_ranks" in loaded["progression"], "Missing progression/career_ranks.json")
        require("upgrades" in loaded["progression"], "Missing progression/upgrades.json")
        require("fleet_rules" in loaded["progression"], "Missing progression/fleet_rules.json")
        validate_difficulty(loaded["progression"]["difficulty_scaling"])
        validate_career_ranks(loaded["progression"]["career_ranks"], catalogs)
        validate_sector_progression(
            loaded["sectors"],
            loaded["progression"]["career_ranks"],
        )
        validate_upgrades(loaded["progression"]["upgrades"], catalogs)
        validate_fleet_rules(
            loaded["progression"]["fleet_rules"],
            loaded["progression"]["career_ranks"],
            catalogs,
        )
        validate_ships(
            loaded["ships"],
            loaded["progression"]["fleet_rules"],
            loaded["progression"]["career_ranks"],
            catalogs,
        )
        require("ship_customization" in loaded["cosmetics"], "Missing cosmetics/ship_customization.json")
        validate_cosmetics(
            loaded["cosmetics"]["ship_customization"],
            loaded["progression"]["career_ranks"],
            catalogs,
        )
        require(len(loaded["biomes"]) >= 50, "Destination expansion requires at least 50 biomes")
        require(len(loaded["sectors"]) >= 59, "Destination expansion requires at least 59 authored sectors")
        primary_assets = {
            str(item["visual_profile"]["primary_asset"])
            for item in loaded["biomes"].values()
        }
        require(
            len(primary_assets) == len(loaded["biomes"]),
            "Every destination biome must own a unique primary asset",
        )

        print(
            "Content validation passed: "
            f"{len(loaded['biomes'])} biome(s), "
            f"{len(loaded['sectors'])} sector(s), "
            f"{len(loaded['salvage'])} salvage definition(s), "
            f"{len(loaded['landmarks'])} landmark(s), "
            f"{len(loaded['modifiers'])} modifier(s), "
            f"{len(loaded['cosmetics'])} cosmetic set(s), "
            f"{len(loaded['ships'])} ship(s)."
        )
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
