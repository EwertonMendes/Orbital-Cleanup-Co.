# Architecture

## Guiding constraint

Architecture exists to support the game. Reusability is valuable only where Orbital Cleanup Co. already needs the abstraction.

## Current runtime root

The application starts at `src/core/app/app_root.tscn`.

`AppRoot` owns explicit service nodes instead of hidden global gameplay dependencies:

- `BuildInfo` — build/provider metadata;
- `PlatformService` — project-owned bridge to the Web provider;
- `SettingsService` — locale and user settings persistence;
- `SaveService` — versioned save envelope;
- `AudioService` — audio settings/application;
- `InputService` — pointer/keyboard, touch and gamepad input-mode detection;
- `SceneRouter` — controlled player-facing screen replacement.

The service context is passed to routed screens that opt into `configure(context)`.

## Layout

```text
src/
  core/
    app/
    audio/
    input/
    save/
    settings/
    platform/
    build/
    utilities/
  game/
    ship/
    salvage/
    sector/
    contracts/
    progression/
    economy/
    customization/
    discovery/
  ui/
    screens/
    hud/
    components/
    themes/
  debug/
    sector_preview/

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

web/
  shell/
  platform/
```

## Core vs game

Core modules must not know Orbital Cleanup Co. business rules. Game modules may depend on core services; core must not depend on game modules.

The current core surface is intentionally small. Do not add generic managers until the game proves a real need.

## UI architecture

Player-facing screens live in `src/ui/screens/`. Reusable visual behavior lives in `src/ui/components/`; shared palette/control styling lives in `src/ui/themes/`.

Current visual primitives include:

- `OccPanelFrame` with glass/metal variants;
- `OccActionButton`;
- `OccPalette`;
- the project `Theme`.

Screens should compose these primitives instead of duplicating styling. See `docs/UI_GUIDELINES.md`.

## Movement architecture

The movement slice lives under `src/game/ship/` and is intentionally game-specific rather than part of reusable core.

- `ShipMovementTuning` stores feel/balance values outside presentation code.
- `ShipSteering` contains pure pointer/deadzone intent math.
- `PlayerShip` owns physics and collision response.
- `ShipVisuals`, `EngineTrail` and `ShipCamera` own presentation feedback.
- `InputService` only exposes generic navigation/pointer state; it does not know ship rules.

The training flight is a temporary authored playground for validating movement. It is not the future Sector Engine and must not become a per-sector architecture.

## Web boundary

Godot gameplay does not call CrazyGames, GamePix, GameMonetize or future portal globals. JavaScript adapters expose a stable project-owned surface through the Web bridge. Builds select a provider through configuration.

GitHub Pages and PR previews use `debug`.

## Save contract

Save data uses a versioned envelope. Schema migrations will be added before a public progression-bearing release. Do not silently change persisted semantics after that point.

## Data-driven sector runtime

The future Sector Engine owns loading and validating BiomeDefinition, SectorDefinition, SalvageDefinition, LandmarkDefinition, ContractDefinition and ModifierDefinition.

A generic `SalvageObject.tscn` is configured by data rather than duplicated per item. Normal sector variants must not require sector-specific scripts.

## Determinism

Procedural systems use explicit seeded RNG streams. Given the same relevant version/configuration and seed, debug reproduction should be practical.

## Performance posture

Start with simple bounded spawning and object pooling. Add chunk streaming only when profiling shows a need. Avoid thousands of active physics bodies and expensive full-screen shaders in the browser.

## Salvage loop architecture

The first recovery slice is implemented under `src/game/salvage/` and is intentionally split by responsibility:

- `SalvageDefinition` owns authored salvage properties such as id, sprite, mass, collection time, cargo footprint and future economy/cleanliness values.
- `SalvageObject.tscn` is the single generic runtime object. Different salvage types do not get dedicated scenes or scripts.
- `TractorBeam` owns automatic nearby-target acquisition, pulling, collection progress and beam presentation.
- `CargoHold` owns capacity and the in-flight manifest.
- `UnloadZone` owns depot interaction and triggers cargo unload when the player returns.
- `PlayerShip` exposes salvage/cargo state through signals so HUD code observes gameplay instead of calculating it.

The authored training flight currently places several generic salvage instances directly as a controlled vertical-slice playground. This placement is temporary. The next Sector Engine phase replaces authored scene placement with sector/content definitions while keeping the same `SalvageObject`, `TractorBeam` and `CargoHold` runtime.

Browser smoke waits for a real `[Salvage] COLLECTED` lifecycle marker after deployment, so Web CI verifies that the automatic recovery loop executes rather than only confirming that the scene renders.

## Data-driven Sector Engine

The Sector Engine is now an active runtime rather than a future placeholder.

The pipeline is:

```text
JSON content
  → ContentRegistry
  → DifficultyScaler
  → SectorGenerator(seed)
  → deterministic generation plan
  → SectorRuntime
  → generic salvage / obstacle / landmark scenes
```

Responsibilities are deliberately separated:

- `ContentRegistry` resolves authored JSON and converts salvage JSON into runtime `SalvageDefinition` resources.
- `DifficultyScaler` reads centralized configurable curves.
- `SectorGenerator` is pure composition logic: seed, weights, modifiers, placement and generation signature.
- `SectorRuntime` instantiates the generated plan.
- `SectorBackdrop` renders bounds/palette without knowing a sector ID.
- `SectorObstacle` and `SectorLandmark` are generic runtime scenes.

The player-facing flight scene contains no normal salvage objects and no normal sector obstacles. Those are generated by `SectorRuntime`.

`earth_training_01` and `earth_training_02` are intentionally two data-only variants using the same runtime. CI asserts that the same seed is deterministic and that the second sector produces a different signature without new code.

The authored prototype `.tres` salvage definitions and the temporary `TrainingSpace` implementation were retired once the JSON runtime became authoritative.

The full contract/economy/progression loop is intentionally not part of this layer. The sector plan carries contract metadata so the next vertical-slice feature can consume it without moving sector-generation responsibilities into UI code.
