# Architecture

## Guiding constraint

Architecture exists to support the game. Reusability is valuable only where Orbital Cleanup Co. already needs the abstraction.

## Target layout

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

Potentially extractable core modules are InputService, SaveService, AudioService, SettingsService, PlatformService, BuildInfo, SceneRouter and a small signal/event layer.

## Web boundary

Godot gameplay does not call CrazyGames, GamePix, GameMonetize or future portal globals. JavaScript adapters expose a stable project-owned surface through the Web bridge. Builds select a provider through configuration.

GitHub Pages always selects `debug`.

## Data-driven sector runtime

The future Sector Engine owns loading and validating BiomeDefinition, SectorDefinition, SalvageDefinition, LandmarkDefinition, ContractDefinition and ModifierDefinition.

A generic `SalvageObject.tscn` is configured by data rather than duplicated per item. Landmarks should similarly be data/configuration first; genuinely unique runtime behavior must justify a reusable generic capability.

## Determinism

Procedural systems use explicit seeded RNG streams. Given the same relevant version/configuration and seed, debug reproduction should be practical. Never rely on implicit global randomness for sector generation.

## Performance posture

Start with simple bounded spawning and object pooling. Add chunk streaming only when profiling shows a need. Avoid thousands of active physics bodies and expensive full-screen shaders in the browser.
