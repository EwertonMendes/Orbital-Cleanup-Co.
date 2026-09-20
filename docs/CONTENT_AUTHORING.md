# Content Authoring

The full schema/validator system arrives with the Data-Driven Sector Engine PR. This document defines the authoring contract in advance.

## Core rule

Creating an ordinary sector must be a data-only change. It must not require new GDScript.

Expected content roots:

```text
content/biomes/
content/sectors/
content/salvage/
content/salvage_tables/
content/landmarks/
content/contracts/
content/modifiers/
content/progression/
content/cosmetics/
```

The future `tools/validate_content.py` will reject invalid JSON, duplicate IDs, unknown references, missing assets, invalid ranges/weights and relevant cycles.

## AI workflow

A request such as:

> Create five Blue Nebula sectors from difficulty 7–12 using only existing assets and landmarks. Include two variations using the Derelict Explorer landmark.

should result in:

1. read schemas;
2. inspect available assets/data;
3. inspect the biome and referenced definitions;
4. generate only required content files;
5. run the validator;
6. open/update a content PR;
7. use deep-link previews such as `?sector=<id>`;
8. wait for owner approval.

No code should be added for those normal sector variants.

## Data principles

- IDs are stable machine identifiers.
- Display names use localization keys.
- Economy and difficulty curves are centralized.
- Asset paths must resolve to vendored/licensed files.
- Weighted tables are explicit and validated.
- Seeds are stored/logged for reproduction.
- Modifiers transform existing runtime parameters instead of duplicating whole levels.
