# Asset Provenance

Orbital Cleanup Co. imports third-party assets only as curated, traceable source material. The current application icon remains original project material.

Every third-party source directory must include:

- `SOURCE.md`
- `LICENSE.txt`

The repository validator enforces this contract.

## Asset registry

| Asset | Creator | Official URL | License | Use | Status |
| --- | --- | --- | --- | --- | --- |
| Space Shooter Remastered | Kenney | https://kenney.nl/assets/space-shooter-remastered | CC0 | primary ship, meteors/debris, beam/engine feedback | **curated subset imported** |
| Simple Space | Kenney | https://kenney.nl/assets/simple-space | CC0 | station, satellites and environmental silhouettes | **curated subset imported** |
| UI Pack - Sci-Fi | Kenney | https://kenney.nl/assets/ui-pack-sci-fi | CC0 | original physical console chrome, cursor states and semantic color variants | **curated subset imported** |
| Space Shooter Extension | Kenney | https://kenney.nl/assets/space-shooter-extension | CC0 | possible future space props | approved source; not imported |
| Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0 | hover/select/confirm/menu SFX | **curated subset imported** |
| Sci-fi Sounds | Kenney | https://kenney.nl/assets/sci-fi-sounds | CC0 | engine/beam/machinery/environmental SFX | approved source; not imported |
| 2D Planet Pack 2 | Screaming Brain Studios | https://screamingbrainstudios.itch.io/2d-planet-pack-2 | CC0 | curated planet/moon/sun backgrounds | approved source; not imported |
| Neuropol | Ray Larabie / Typodermic Fonts | https://typodermicfonts.com/public-domain/ | CC0 1.0 / public domain | principal display/game-identity typeface | **imported** |
| Inter | The Inter Project Authors | https://github.com/rsms/inter | SIL OFL 1.1 | readable body copy and utility UI | **variable font imported** |
| JetBrains Mono | JetBrains | https://github.com/JetBrains/JetBrainsMono | SIL OFL 1.1 | telemetry, credits, XP and numeric metadata | **variable font imported** |
| Magic Space | CodeManu | https://opengameart.org/content/magic-space | CC0 | candidate calm sci-fi music loop | candidate; not imported |
| Singularity | vitalezzz | https://opengameart.org/content/singularity-0 | CC0 | candidate calm sci-fi music loop | candidate; not imported |

## Current Kenney import

The repository keeps a curated subset rather than dumping complete packs.

The Operations redesign imports the original UI Pack - Sci-Fi files with their upstream folder/color identity intact:

- neutral `Extra/Double` raised/pressed buttons and screw/glass panels;
- original Blue, Grey, Green, Red and Yellow header/blade variants;
- original blue/green/yellow progress art;
- original cursor arrow, point and pressed states;
- original colored status squares.

No runtime tint or recolor is applied to these UI textures. Resizable chrome uses 9-slice geometry so corners, screws and bevels stay intact.

The Interface Sounds import contains only three CC0 cues: hover/select, click/activate and back/close. One blue player ship, engine feedback, selected space props and hazards from the other Kenney packs remain as before.

Enemies, guns and lasers are intentionally excluded because Orbital Cleanup Co. has no combat. Each source directory records the official Kenney page, CC0 license and transfer provenance.

## Import policy

- Curate only assets actually used or intentionally staged for near-term work.
- Do not hotlink runtime assets.
- Do not import combat art merely because it exists in a source pack.
- Prefer transformations, composition, shaders and project styling over duplicating recolored source files.
- Do not introduce Git LFS until measured repository/build size justifies it and the owner approves it.

## Visual identity

Third-party packs are ingredients, not the finished art direction. Cohesion comes from Orbital Cleanup Co.'s palette, composition, motion, typography, particles, layout and reusable components.

See [UI Guidelines](UI_GUIDELINES.md).


## Typography

Orbital Cleanup Co. uses a three-family semantic typography system:

- **Neuropol** is the principal stylized game/display face. It is sourced from Ray Larabie's Typodermic public-domain catalog under CC0; the repository records the official source and the transfer mirror used for the binary.
- **Inter** is the readable body/utility family under SIL OFL 1.1.
- **JetBrains Mono** is the telemetry/value family under SIL OFL 1.1.

All three families are applied through shared Godot Theme type variations. Oxanium has been removed from the repository.

## Project-owned planet artwork

The launch-biome planets under `assets/original/planets/` are original Orbital Cleanup Co. vector artwork authored directly for this project:

- Earth Orbit;
- Lunar Belt;
- Mars Freight Route;
- Blue Nebula giant.

They are not derived from the approved-but-unimported external planet packs listed above and therefore do not add a third-party runtime dependency. Editable SVG source remains in Git, while Godot imports it as texture data at build time. A shared project shader supplies subtle rotation, atmosphere glow and shimmer instead of baking animation into duplicate image files.


## Project-owned orbital landmark artwork

Large sector landmarks now use original Orbital Cleanup Co. SVG artwork under `assets/original/landmarks/` instead of scaling small source-pack props into major structures.

The current set contains eight editable source assets: service satellite, cargo waystation, relay satellite, mining rig, fractured moonlet, communications array, research outpost and derelict explorer wreck.

These files are authored for the OCC palette and top-down readability requirements. They add no third-party licensing or runtime dependency. Kenney remains useful for smaller source props, hazards and salvage, while major authored structures are now part of the project's own visual identity.

## Expanded destination artwork

The destination expansion adds 46 original editable SVG primary visuals under `assets/original/destinations/`. They are authored in-repository and introduce no new third-party dependency.

The visual system intentionally treats these as generic primary destination artwork rather than assuming every scene is a planet. The same renderer can therefore present planets, moons, stars, stations, wreck fields, nebulae, pulsars, black holes and supernova remnants.


## Project-owned interface artwork

The professional UI pass adds editable SVG accents under `assets/original/ui/`. They are authored specifically for Orbital Cleanup Co. and are used as proportion-safe accents rather than stretched panel backgrounds. Layout remains container/theme driven.

## Project-owned salvage artwork

The salvage pass adds **25 editable SVG silhouettes** under `assets/original/salvage/`, one for every current recoverable item. The art uses a shared OCC material language with category accents while rarity animation remains runtime-driven. This replaces the previous state where most salvage definitions reused the same two satellite sprites and makes each salvage table visually diverse without creating per-item scenes.
