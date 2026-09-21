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
    for item_id, data in items.items():
        label = f"salvage/{item_id}"
        require_keys(data, (
            "display_name_key", "sprite", "category", "rarity", "base_value", "mass",
            "collect_duration", "cleanliness_value", "cargo_units", "visual_scale",
            "collision_radius", "tags",
        ), label)
        require_localization_key(data["display_name_key"], label, catalogs)
        require_asset(data["sprite"], f"{label}.sprite")
        sprite_name = Path(str(data["sprite"])).name.lower()
        require(
            "meteor" not in sprite_name,
            f"{label}.sprite: meteor silhouettes are reserved for hazards; use a recoverable-object asset",
        )
        require(data["rarity"] in {"common", "uncommon", "rare", "epic"}, f"{label}: invalid rarity")
        require_number(data["base_value"], f"{label}.base_value", 0)
        require_number(data["mass"], f"{label}.mass", 0.01)
        require_number(data["collect_duration"], f"{label}.collect_duration", 0.01)
        require_number(data["cleanliness_value"], f"{label}.cleanliness_value", 0)
        require_number(data["cargo_units"], f"{label}.cargo_units", 1, 12)
        require_number(data["visual_scale"], f"{label}.visual_scale", 0.2, 4)
        require_number(data["collision_radius"], f"{label}.collision_radius", 6, 120)
        require(isinstance(data["tags"], list), f"{label}.tags must be an array")
        require(len(data["tags"]) == len(set(data["tags"])), f"{label}.tags contains duplicates")


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


def validate_landmarks(items: dict[str, dict[str, Any]], catalogs: dict[str, set[str]]) -> None:
    for item_id, data in items.items():
        label = f"landmarks/{item_id}"
        require_keys(data, (
            "display_name_key", "sprite", "scale", "reserved_radius", "placement_radius",
            "collision", "spin_speed_range", "drift_amplitude", "ambient_effect",
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
        collision = data["collision"]
        require(isinstance(collision, dict), f"{label}.collision must be an object")
        shape = collision.get("shape")
        require(shape in {"circle", "box"}, f"{label}.collision.shape must be circle or box")
        if shape == "circle":
            require(set(collision) == {"shape", "radius"}, f"{label}.collision circle fields are invalid")
            collision_extent = require_number(collision.get("radius"), f"{label}.collision.radius", 20, 600)
        else:
            require(set(collision) == {"shape", "size"}, f"{label}.collision box fields are invalid")
            size = collision.get("size")
            require(isinstance(size, list) and len(size) == 2, f"{label}.collision.size must contain two values")
            width = require_number(size[0], f"{label}.collision.size[0]", 40, 900)
            height = require_number(size[1], f"{label}.collision.size[1]", 40, 900)
            collision_extent = max(width, height) * 0.5
        require(reserved_radius >= collision_extent + 60, f"{label}.reserved_radius must leave navigation clearance around collision")
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
        planet_asset = visual.get("planet_asset")
        require(isinstance(planet_asset, str) and planet_asset.endswith(".svg"), f"{label}: planet asset must be an SVG")
        require((ROOT / planet_asset.removeprefix("res://")).exists(), f"{label}: Missing planet asset: {planet_asset}")
        anchor = visual.get("planet_anchor")
        require(isinstance(anchor, list) and len(anchor) == 2, f"{label}.visual_profile.planet_anchor must contain two values")
        require_number(anchor[0], f"{label}.visual_profile.planet_anchor[0]", 0, 1)
        require_number(anchor[1], f"{label}.visual_profile.planet_anchor[1]", 0, 1)
        require_number(visual.get("planet_scale"), f"{label}.visual_profile.planet_scale", 0.2, 5)
        require_number(visual.get("planet_parallax"), f"{label}.visual_profile.planet_parallax", 0, 0.5)
        require_number(visual.get("traffic_count"), f"{label}.visual_profile.traffic_count", 0, 24)
        require_number(visual.get("dust_density"), f"{label}.visual_profile.dust_density", 0, 2)

        environment = data["environment"]
        require(isinstance(environment, dict), f"{label}.environment must be an object")
        require_number(environment.get("salvage_mass_multiplier"), f"{label}.environment.salvage_mass_multiplier", 0.5, 2)
        volumes = environment.get("volumes")
        require(isinstance(volumes, list), f"{label}.environment.volumes must be an array")
        allowed_kinds = {
            "gravity_well", "safe_corridor", "drift_current", "visibility_pocket",
            "scanner_interference", "tractor_distortion", "magnetic_zone",
        }
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
            require_number(obstacle.get("collision_radius"), f"{label}.obstacles[{index}].collision_radius", 1)
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
    allowed_base = {"scan_range", "collection_speed_multiplier", "cargo_capacity"}
    require(set(base_ship) == allowed_base, f"{label}.base_ship must define exactly {sorted(allowed_base)}")
    for key, value in base_ship.items():
        require_number(value, f"{label}.base_ship.{key}", 0.01)

    upgrades = data.get("upgrades")
    require(isinstance(upgrades, list) and len(upgrades) >= 3, f"{label}.upgrades must contain at least three upgrades")
    seen: set[str] = set()
    allowed_effects = {"scan_range_add", "collection_speed_multiplier_add", "cargo_capacity_add"}
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

    expected_categories = {"hull", "paint", "trail", "beam"}
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
            ranks_by_id[option_id] = str(unlock_rank)

            if category == "hull":
                require_asset(option.get("texture"), f"{label}.{category}.{option_id}.texture")
            elif category == "paint":
                require(HEX_COLOR_RE.fullmatch(str(option.get("color", ""))) is not None, f"{label}.{category}.{option_id}.color: expected #RRGGBB")
                require_number(option.get("strength"), f"{label}.{category}.{option_id}.strength", 0, 1)
            elif category == "trail":
                for color_key in ("tail_color", "head_color", "glow_color"):
                    require(HEX_COLOR_RE.fullmatch(str(option.get(color_key, ""))) is not None, f"{label}.{category}.{option_id}.{color_key}: expected #RRGGBB")
                require_number(option.get("width"), f"{label}.{category}.{option_id}.width", 2, 24)
                require_number(option.get("lifetime"), f"{label}.{category}.{option_id}.lifetime", 0.1, 2.0)
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
        validate_difficulty(loaded["progression"]["difficulty_scaling"])
        validate_career_ranks(loaded["progression"]["career_ranks"], catalogs)
        validate_sector_progression(
            loaded["sectors"],
            loaded["progression"]["career_ranks"],
        )
        validate_upgrades(loaded["progression"]["upgrades"], catalogs)
        require("ship_customization" in loaded["cosmetics"], "Missing cosmetics/ship_customization.json")
        validate_cosmetics(
            loaded["cosmetics"]["ship_customization"],
            loaded["progression"]["career_ranks"],
            catalogs,
        )

        print(
            "Content validation passed: "
            f"{len(loaded['biomes'])} biome(s), "
            f"{len(loaded['sectors'])} sector(s), "
            f"{len(loaded['salvage'])} salvage definition(s), "
            f"{len(loaded['landmarks'])} landmark(s), "
            f"{len(loaded['modifiers'])} modifier(s), "
            f"{len(loaded['cosmetics'])} cosmetic set(s)."
        )
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
