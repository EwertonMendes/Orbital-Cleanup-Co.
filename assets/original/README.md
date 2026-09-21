# Original Orbital Cleanup Co. assets

The assets in this directory are original project artwork authored for Orbital Cleanup Co. and committed as editable source assets.

## Planets

The SVG planet illustrations are deliberately stylized for the game's clean cozy sci-fi visual language. They are not derived from third-party imagery.

Runtime animation, atmosphere glow and subtle surface movement are applied by `src/game/visual/planet_surface.gdshader`.

## Orbital landmarks

The SVG artwork under `assets/original/landmarks/` is authored specifically for OCC's top-down navigation language.

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
