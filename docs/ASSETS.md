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
| UI Pack - Sci-Fi | Kenney | https://kenney.nl/assets/ui-pack-sci-fi | CC0 | raw material for OCC reusable UI chrome | **curated subset imported** |
| Space Shooter Extension | Kenney | https://kenney.nl/assets/space-shooter-extension | CC0 | possible future space props | approved source; not imported |
| Interface Sounds | Kenney | https://kenney.nl/assets/interface-sounds | CC0 | hover/select/confirm/menu SFX | approved source; not imported |
| Sci-fi Sounds | Kenney | https://kenney.nl/assets/sci-fi-sounds | CC0 | engine/beam/machinery/environmental SFX | approved source; not imported |
| 2D Planet Pack 2 | Screaming Brain Studios | https://screamingbrainstudios.itch.io/2d-planet-pack-2 | CC0 | curated planet/moon/sun backgrounds | approved source; not imported |
| Oxanium | Google Fonts distribution | https://github.com/google/fonts/tree/main/ofl/oxanium | SIL OFL 1.1 | primary readable futuristic interface typeface | **variable font imported** |
| Magic Space | CodeManu | https://opengameart.org/content/magic-space | CC0 | candidate calm sci-fi music loop | candidate; not imported |
| Singularity | vitalezzz | https://opengameart.org/content/singularity-0 | CC0 | candidate calm sci-fi music loop | candidate; not imported |

## Current Kenney import

The visual-foundation PR imports **17 PNG files** from the three requested Kenney packs rather than dumping the full packs into the repository.

Curated material includes:

- six Sci-Fi UI textures for panels, buttons and bars;
- one blue player ship, one engine-speed effect, three grey meteors and one beam part from Space Shooter Remastered;
- two satellites, one station, one detailed meteor and one star from Simple Space.

Enemies, guns and lasers are intentionally excluded because Orbital Cleanup Co. has no combat.

Each imported source directory records the official Kenney page, CC0 license, import date and the pinned public mirror commit used to transfer binary files into Git.

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

Oxanium is imported from the Google Fonts repository as the variable `Oxanium[wght].ttf` file under SIL OFL 1.1. The font is applied through the shared Godot Theme so screens do not embed font paths individually.
