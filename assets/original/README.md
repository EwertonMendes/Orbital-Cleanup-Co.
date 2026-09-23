# Original Orbital Cleanup Co. assets

The assets in this directory are original project artwork authored for Orbital Cleanup Co. and committed as editable source assets.

## Planets

The SVG planet illustrations are deliberately stylized for the game's clean cozy sci-fi visual language. They are not derived from third-party imagery.

Runtime animation, atmosphere glow and subtle surface movement are applied by `src/game/visual/planet_surface.gdshader`.

The original launch SVGs remain in the repository as editable/fallback artwork. Higher-detail runtime tests may live beside them as optimized raster assets. `earth_orbit_hd.webp` is the first such test: it preserves transparency and high-detail rendering while avoiding the memory/download cost of using the full uploaded source image directly.

## Player ships

`assets/original/ships/pioneer_01_hd.webp` is the first project-owned HD ship test. The previous Kenney player ship remains in `assets/third_party/` for rollback/reference while the runtime points to the new Pioneer-01 artwork.

Ship source art is normalized through scene scale rather than destructively stretched. The runtime sprite remains centered and the existing engine/trail anchor stays aligned with the rendered main engine.

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

## Destination primary artwork

The `destinations/` folder contains 46 additional project-owned SVG primary visuals authored specifically for Orbital Cleanup Co. They cover Solar System worlds and moons, the Solar corona, dwarf planets, abandoned infrastructure, stellar objects, black holes, exoplanets, nebulae and a supernova remnant.

Together with the four original launch visuals under `planets/`, the runtime has one unique primary asset for each of 50 destination biomes.

