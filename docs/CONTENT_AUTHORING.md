# Content Authoring

Orbital Cleanup Co. treats normal playable content as data. A normal sector must not require a new Godot scene or a new GDScript file.

The canonical authored roots are:

```text
content/
  biomes/
  sectors/
  salvage/
  salvage_tables/
  landmarks/
  contracts/
  modifiers/
  progression/
  cosmetics/
```

The runtime reads JSON through `ContentRegistry`. The CI runs `tools/validate_content.py` before Godot import, so invalid authored content fails quickly.

## Core authoring rule

If creating a normal sector such as `mars_freight_17` requires adding sector-specific code, stop and fix the architecture instead.

The normal flow is:

1. reuse or add valid definitions;
2. add a sector JSON;
3. run the content validator;
4. let Godot import/export;
5. test the PR preview;
6. merge only after explicit approval.

## Schemas

The explicit contracts live in:

```text
schemas/biome.schema.json
schemas/sector.schema.json
schemas/salvage.schema.json
schemas/landmark.schema.json
schemas/contract.schema.json
schemas/modifier.schema.json
schemas/salvage_table.schema.json
schemas/difficulty_scaling.schema.json
schemas/career_ranks.schema.json
schemas/upgrades.schema.json
```

The Python validator is authoritative in CI and additionally checks cross-file references, asset existence and localization coverage.

## IDs and filenames

Every content file uses a stable lowercase snake_case ID.

The filename must match the ID exactly:

```text
content/sectors/earth_training_01.json
```

must contain:

```json
{
  "id": "earth_training_01"
}
```

Do not rename published IDs casually. Other definitions and saves may eventually reference them.

## Localization

Player-facing names are localization keys, never hardcoded display text inside content JSON.

Example:

```json
{
  "display_name_key": "BIOME_EARTH_ORBIT"
}
```

That key must exist in all supported catalogs:

- `i18n/en.po`
- `i18n/pt_BR.po`
- `i18n/es_ES.po`

The validator fails if any supported locale is missing the key.

## Salvage definitions

A salvage definition owns gameplay/content values and the vendored sprite path.

Example:

```json
{
  "id": "scrap_fragment",
  "display_name_key": "SALVAGE_SCRAP_FRAGMENT",
  "sprite": "res://assets/third_party/kenney_space_shooter/meteors/meteor_grey_small.png",
  "category": "scrap",
  "rarity": "common",
  "base_value": 12,
  "mass": 0.65,
  "collect_duration": 0.55,
  "cleanliness_value": 1.0,
  "cargo_units": 1,
  "visual_scale": 0.72,
  "collision_radius": 20.0,
  "tags": ["metal", "training"]
}
```

All salvage types use the same runtime scene: `SalvageObject.tscn`.

Do not create a scene per salvage type.

## Salvage tables

Weighted tables define what may spawn.

Example:

```json
{
  "id": "earth_training",
  "entries": [
    { "salvage": "scrap_fragment", "weight": 34 },
    { "salvage": "sensor_pod", "weight": 18 }
  ]
}
```

Weights must be positive. Duplicate salvage entries in one table are rejected.

Sector generation may apply a rarity multiplier from difficulty/modifiers, but authored weights remain the baseline.

## Biomes

A biome is a curated kit, not a level.

It constrains:

- palette;
- salvage tables;
- allowed landmarks;
- allowed modifiers;
- spawn rules;
- available obstacle visuals.

Example responsibilities for `earth_orbit.json`:

```text
palette
allowed salvage table ids
allowed landmark ids
allowed modifier ids
starter cluster rules
edge margin / spacing
meteor visual definitions
```

A sector may only reference tables/landmarks/modifiers allowed by its biome. CI enforces this.

## Sectors

A sector chooses a biome, deterministic seed, difficulty and authored composition constraints.

Current example:

```json
{
  "id": "earth_training_01",
  "display_name_key": "OPS_CONTRACT_TITLE",
  "biome": "earth_orbit",
  "seed": 18422,
  "difficulty": 1,
  "map": {
    "half_extents": [4800.0, 3000.0],
    "debris_density": 0.75,
    "cluster_count": 4
  },
  "salvage_tables": [
    { "id": "earth_training", "weight": 100 }
  ],
  "landmarks": ["service_satellite"],
  "contract": {
    "type": "standard_cleanup",
    "target_percent": 70
  },
  "modifiers": ["light_debris"],
  "depot": {
    "position": [-720.0, -520.0]
  }
}
```

Creating another Earth Orbit variation can therefore be a JSON-only change with a different seed/difficulty/modifier.

`earth_training_02.json` exists specifically as an executable proof of this rule. Core contract tests require it to produce a deterministic but different generation signature from Route 01.

## Determinism

`SectorGenerator` uses the sector seed for authored procedural placement.

For the same game/content version and the same sector definition:

- salvage selection is repeatable;
- generated positions are repeatable;
- obstacle selection/placement is repeatable;
- landmark placement is repeatable.

The runtime prints:

```text
[Sector] READY id=<id> seed=<seed> ... signature=<signature>
```

This marker is used for QA and reproduction.

## Difficulty scaling

Difficulty-derived values live in:

```text
content/progression/difficulty_scaling.json
```

Current curves include:

- salvage count;
- obstacle count;
- rare-weight multiplier;
- mass multiplier;
- reward multiplier.

Do not add level-specific `if level == ...` logic for ordinary scaling.

Curves are capped/configurable so extreme future contract levels remain bounded.

## Modifiers

Modifiers transform existing generator/runtime parameters.

Example:

```json
{
  "id": "dense_debris",
  "display_name_key": "MODIFIER_DENSE_DEBRIS",
  "runtime": {
    "salvage_count_multiplier": 1.2,
    "obstacle_count_multiplier": 1.35,
    "rare_weight_multiplier": 1.05
  }
}
```

A modifier does not duplicate a sector and does not own a custom phase script.

## Landmarks

Landmarks are visually strong composition elements.

The current generic landmark definition contains:

- sprite;
- scale;
- reserved radius;
- placement radius;
- ambient-effect ID.

The runtime uses one generic `SectorLandmark` class. Future landmark behavior should remain configurable wherever practical.

## Contracts in this phase

Contract definitions are already data contracts, but full completion/payout/progression behavior belongs to the next vertical-slice delivery.

The current Sector Engine only validates and carries contract metadata.

## Asset rules

Content may only point to assets already vendored under `assets/`.

Do not:

- hotlink runtime assets;
- reference arbitrary remote URLs;
- add unlicensed files;
- bypass `docs/ASSETS.md`.

The validator fails on missing `res://assets/` paths.

## Validation

Run:

```bash
python3 tools/validate_content.py
```

The validator currently rejects:

- invalid JSON;
- missing required directories/schemas;
- duplicate IDs;
- filename/ID mismatch;
- missing localization keys;
- missing assets;
- invalid numeric ranges;
- invalid/duplicate table entries;
- zero/negative weights;
- unknown biome/table/landmark/contract/modifier/salvage references;
- sector content not allowed by its biome;
- invalid contract target ranges;
- invalid difficulty curves.

Example failure:

```text
ERROR: sectors/mars_07: Unknown landmark: banana_station
```

## AI content workflow

A request such as:

> Create five Blue Nebula sectors from difficulty 7–12 using only existing assets and landmarks. Include two variations using the Derelict Explorer landmark.

should be handled as follows:

1. read this document and the relevant schemas;
2. inspect existing biome, salvage tables, landmarks and modifiers;
3. reuse existing licensed assets;
4. add only required JSON/localization entries;
5. run `tools/validate_content.py`;
6. run normal CI/Godot/Web checks;
7. open/update a content PR;
8. provide playable previews/deep links when supported;
9. wait for owner approval.

Do not add code merely because content generation is being performed by AI.

## Current limitation

Deep-link sector selection (`?sector=<id>`) and the visual Sector Preview tool belong to the later Endless Contracts / Developer Tools delivery. Until then, the flight screen defaults to `earth_training_01`, while tests can instantiate any valid sector directly through `SectorGenerator`.

## Career and upgrades

Career thresholds live in `content/progression/career_ranks.json`. Rank XP thresholds must be strictly increasing and every display key must exist in all supported locales.

The first ship upgrade definitions live in `content/progression/upgrades.json`. Each definition owns:

- stable ID;
- localized name/description keys;
- maximum level;
- base cost;
- cost multiplier;
- additive gameplay effects.

The base ship values are authored in the same file. Do not hardcode upgrade prices or final Tractor Beam/cargo values into UI scripts.

Current validated effect IDs are:

```text
scan_range_add
collection_speed_multiplier_add
cargo_capacity_add
```

Adding an unknown effect fails content validation until the runtime intentionally supports it.

