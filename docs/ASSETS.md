# Asset Provenance

No third-party art/audio pack is imported in the bootstrap PR. The current SVG application icon is original project material.

All third-party files must live under `assets/third_party/<source>/` and include:

- `SOURCE.md`
- `LICENSE.txt`

This registry must be updated in the same PR that imports an asset.

## Approved/planned source pool

| Asset | Creator | Original URL | License | Planned use | Status |
| --- | --- | --- | --- | --- | --- |
| Space Shooter Remastered | Kenney | https://kenney.nl/assets/space-shooter-remastered | CC0 | ships, meteors, debris, space props | approved source; not imported |
| Space Shooter Extension | Kenney | https://kenney.nl/assets/space-shooter-extension | CC0 | satellites, station/rocket parts, extra debris | approved source; not imported |
| Simple Space | Kenney | https://kenney.nl/assets/simple-space | CC0 | radar/minimap/icons and select space elements | approved source; not imported |
| UI Pack - Sci-Fi | Kenney | https://kenney.nl/assets/ui-pack-sci-fi | CC0 | raw material for OCC UI theme | approved source; not imported |
| Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0 | hover/select/confirm/menu SFX | approved source; not imported |
| Sci-fi Sounds | Kenney | https://kenney.nl/assets/sci-fi-sounds | CC0 | engine/beam/machinery/environmental SFX | approved source; not imported |
| 2D Planet Pack 2 | Screaming Brain Studios | https://screamingbrainstudios.itch.io/2d-planet-pack-2 | CC0 | curated planet/moon/sun backgrounds | approved source; not imported |
| Oxanium | Severin Meyer / Google Fonts distribution | https://github.com/google/fonts/tree/main/ofl/oxanium | SIL OFL 1.1 | primary futuristic readable typeface | approved source; not imported |
| Magic Space | CodeManu | https://opengameart.org/content/magic-space | CC0 | candidate calm sci-fi music loop | candidate; not imported |
| Singularity | vitalezzz | https://opengameart.org/content/singularity-0 | CC0 | candidate calm sci-fi music loop | candidate; not imported |

The current 2D Planet Pack 2 source page lists 795 planet sprites after later updates; import only a curated subset appropriate to the selected biomes.

## Import policy

Do not dump entire packs into the repository. Curate only assets actually used or intentionally staged for near-term content. Record acquisition date, exact files and modifications in each source's `SOURCE.md`.

Do not hotlink assets at runtime.

Avoid Git LFS initially. Revisit only after measuring repository/build size.

## Visual identity

Third-party packs are ingredients, not the finished art direction. Cohesion comes from Orbital Cleanup Co. composition, palette, shaders, particles, typography, animation, UI theme and branding.
