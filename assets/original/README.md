# Original Orbital Cleanup Co. assets

The assets in this directory are original project artwork authored for Orbital Cleanup Co. and committed as editable source assets.

## Planets

The SVG planet illustrations are deliberately stylized for the game's clean cozy sci-fi visual language. They are not derived from third-party imagery.

Runtime animation, atmosphere glow and subtle surface movement are applied by `src/game/visual/planet_surface.gdshader`.

The original launch SVGs remain in the repository as editable/fallback artwork. Runtime destination definitions now point to project-owned HD raster artwork instead of the legacy SVG primaries.

## Player ships

`assets/original/ships/pioneer_01_hd.webp` is the project-owned HD player ship. The previous Kenney player ship remains in `assets/third_party/` for rollback/reference while the runtime points to the Pioneer-01 artwork.

Ship source art is normalized through scene scale rather than destructively stretched. The runtime sprite remains centered and the existing engine/trail anchor stays aligned with the rendered main engine.

## Orbital landmarks

The original SVG artwork under `assets/original/landmarks/` is authored specifically for OCC's top-down navigation language.

The launch set includes:

- orbital service satellite;
- cargo waystation;
- long-range relay satellite;
- lunar mining rig;
- fractured industrial moonlet;
- communications array;
- Blue Nebula research outpost;
- derelict explorer wreck.

These silhouettes are deliberately larger and more structurally distinct than recoverable salvage. Runtime collision and navigation clearance are authored in landmark JSON rather than baked into the artwork.

The Cargo Waystation and Fractured Moonlet now have HD raster runtime artwork. `texture_reference_size` allows high-resolution landmark textures to preserve their authored gameplay footprint while collision remains independently defined in landmark content.

## Cargo depots

`depots/cargo_depot_hd.webp` is the project-owned HD unload/depot structure used in live flight. The artwork supplies the physical station silhouette, while `UnloadZone` continues to own the gameplay radius, animated rings, cargo-full feedback and unload flash. This keeps interaction feedback procedural and reusable instead of baking it into the texture.

The previous Kenney station asset remains under `assets/third_party/` as a fallback/reference during the art transition.

## Destination primary artwork

Every authored destination biome now uses project-owned HD raster primary artwork at runtime.

The `destinations/` folder covers Solar System worlds and moons, dwarf planets, orbital infrastructure, stellar objects, black holes, exoplanets, nebulae, asteroid regions and supernova remnants. Together with the four original launch HD visuals under `planets/`, all 50 authored biome definitions now resolve to non-SVG primary assets.

The original SVG destination files remain beside the HD artwork only as editable/fallback source material; authored biome definitions no longer depend on them for the primary visual.

## Biome obstacle artwork

All authored biomes use project-owned HD obstacle artwork under `obstacles/`. Every biome is assigned to the closest visual obstacle family so no gameplay scenario falls back to the legacy grey Kenney meteor sprites.

- `earth_orbit/`: dark iron/nickel meteorites;
- `lunar_belt/`: pale cratered regolith boulders;
- `mars_freight/`: rust-orange Martian rock with exposed dark basalt;
- `blue_nebula/`: cold blue/violet mineral fragments.

Obstacle collision remains authored in biome content. `texture_reference_size` normalizes HD raster resolution without changing gameplay footprint, while `sprite_modulate` allows full-color original artwork without changing unrelated rendering.

All 50 authored biome definitions are covered by an explicit `obstacle_art_family`; content validation rejects any fallback to the legacy Kenney meteor sprites.

## HD celestial destination artwork

Destination primary visuals use transparent HD WebP artwork. `primary_reference_size` preserves the authored visual footprint of the former 512px SVG while allowing higher-resolution raster sources.

The HD migration now covers all 46 destination definitions that previously used SVG primaries. This includes planets, moons, dwarf planets, belts, exoplanets, nebulae, stellar phenomena, abandoned orbital structures, factory ruins and ship graveyards.

The final migration also upgrades the Fractured Moonlet landmark with HD artwork and adds landmark-side texture reference normalization so visual resolution remains independent from gameplay collision and reserved navigation radius.

## HD landmark artwork

All eight authored gameplay landmarks now use project-owned raster artwork at runtime. The six remaining SVG landmarks were migrated to transparent HD WebP while preserving their existing collision, placement, reserved radius, drift and spin behavior.

`texture_reference_size` keeps each new 768px raster asset at the visual footprint of its previous authored SVG dimensions, so artwork resolution remains independent from gameplay geometry.

