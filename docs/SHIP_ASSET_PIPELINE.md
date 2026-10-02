# Ship Asset Pipeline

This document is the production contract for the Orbital Cleanup Co. fleet. Ship models are gameplay content; paint, liveries, decals, canopy treatments, body kits, engine FX, trails and Tractor Beam styles are cosmetic layers.

## Runtime contract

A normal ship is added with:

1. one `content/ships/<id>.json` definition;
2. project-owned art under `assets/original/ships/<id>/`;
3. EN / PT-BR / ES localization;
4. content validation.

Adding a normal ship must not require editing `PlayerShip`, `ShipDynamics`, `FlightScreen` or sector code.

The runtime resolves:

`ShipDefinition + per-ship upgrades + equipped modules + cosmetics -> ShipBuildSnapshot -> PlayerShip`

Cosmetics never modify collision or gameplay stats.

## Master art rules

- master canvas: 1024x1024;
- true transparent background;
- top-down orthographic camera;
- nose exactly at 12 o'clock;
- complete craft visible with generous alpha margin;
- consistent soft upper-left light;
- civilian cleanup / recovery / cargo / survey language;
- no weapons, missiles, guns, military insignia, text, logos or baked exhaust trails;
- details must remain readable after gameplay downscaling;
- base geometry must remain pixel-aligned across every derived layer.

Use lossless PNG while authoring masks and layered parts. Runtime opaque/color art may be optimized to WebP after visual approval.

## Per-ship source package

```
assets/original/ships/<ship_id>/
  base.webp
  paint_mask.png
  details.webp
  emissive_mask.png
  thumbnail.webp
  body_kits/
    stock.webp
    ...
```

The complete 20-ship fleet uses the unified fleet-art pipeline. Pioneer-01 again uses the same normalized production style as the other ships, with its own `base.webp`, pixel-aligned RGB paint mask, authored runtime footprint and engine/tractor sockets.

## RGB paint mask

The paint mask must have the exact same canvas and registration as `base.webp`:

- red channel = primary paint region;
- green channel = secondary paint region;
- blue channel = accent paint region;
- black = fixed original material;
- alpha = ship coverage.

Do not ask an image model to redraw the mask from scratch. Generate the approved master first, lock geometry, then derive/segment masks from that exact image.

## Emissive mask

The emissive mask identifies light-emitting pixels only. It must not contain baked glow. Godot owns glow/color/intensity at runtime.

## Body-kit overlays

Body kits are overlays, not alternate hull renders. They must:

- use the exact master canvas, scale, rotation and registration;
- contain only added cosmetic pixels;
- remain transparent everywhere else;
- never modify collision or stats.

Reference-edit prompt:

> Keep the original spaceship completely unchanged and pixel-aligned. Add only the requested cosmetic components. Output only the newly added components on a transparent 1024x1024 canvas using exactly the same ship position, camera, scale and geometry as the provided reference. Do not redraw, resize, rotate, move or reinterpret the original ship.

## Master generation prompt

> Top-down orthographic 2D spaceship sprite for the cozy industrial sci-fi game "Orbital Cleanup Co.". A professional civilian orbital cleanup and recovery service craft, friendly modern industrial design, highly readable silhouette, premium HD game asset, believable functional panels, maintenance hatches, sensor equipment and visible engine nozzles. Camera perfectly perpendicular to the ship, nose pointing exactly upward at 12 o'clock, ship centered in a 1024x1024 canvas, entire craft visible with generous transparent margins. Neutral paintable hull materials with clearly separated primary, secondary and accent panel regions. Subtle realistic material shading, clean stylized details readable when scaled down, soft upper-left lighting. No weapons, no guns, no missiles, no military insignia. No exhaust flames, no engine trail, no tractor beam, no glow extending beyond the hull, no cast shadow, no background, no stars, no text, no logo, no watermark, no motion blur, no perspective, no three-quarter view, no cropped parts. True transparent background. DESIGN BRIEF: [SHIP BRIEF].

## Planned 20-ship fleet

| Ship | Role | Visual brief |
| --- | --- | --- |
| Pioneer-01 | Generalist | Balanced medium civilian recovery craft, rounded wedge, one central engine. |
| Swiftlet-S1 | Agility | Compact rounded delta, lightweight chassis, twin microthrusters. |
| Manta-T1 | Scanner | Wide manta silhouette, central forward scanner, twin engines. |
| Mule-C1 | Cargo | Boxy utility craft with large symmetrical cargo panniers. |
| Vector-V1 | Maneuvering | Compact angular craft with separated vectored thrusters. |
| Angler-T2 | Recovery | Rounded salvage craft with prominent forward tractor housing. |
| Kestrel-S2 | Cruise speed | Long narrow tapered civilian service craft. |
| Pulse-V2 | Boost | Compact craft visually built around oversized propulsion capacitors. |
| Ox-C2 | Stable cargo | Short wide utility ship with reinforced cargo frame. |
| Magnetar-T4 | Tractor range | Forward magnetic coil structures around recovery aperture. |
| Grappler-T5 | Heavy tow | Stocky orbital tug with reinforced recovery yoke. |
| Nomad-V3 | Inertial cargo | Rugged long-duration modular service spacecraft. |
| Beacon-S3 | Long-range sensor | Distinctive sensor crown and short civilian antennas. |
| Comet-X4 | Speed/boost | Extremely tapered craft with one dominant rear engine. |
| Atlas-C4 | Heavy cargo | Large vessel with reinforced cargo spine and four engines. |
| Bastion-H4 | Hazards | Dense rounded-hexagonal protected service hull. |
| Prospector-Q3 | Precision recovery | Survey ship with twin scanner pods and industrial center body. |
| Aurora-E4 | Extreme environments | Smooth insulated hull with visible field-coil structures. |
| Leviathan-C6 | Mega hauler | Very large broad recovery vessel with multiple cargo cells. |
| Horizon-M5 | Modular flagship | Premium platform with obvious standardized side hardpoints. |

## Socket authoring

Engine and tractor sockets live in ship JSON, not baked VFX. Current definitions store socket positions in ship-local Godot coordinates so art can be aligned precisely after import. A future layered source may additionally record normalized authoring coordinates, but runtime sockets remain explicit authored gameplay presentation data.

Every ship must provide at least one engine socket and exactly one tractor socket.

## Collision

Collision belongs to the ship model, never to a cosmetic layer. The current runtime builds the solid player collision from the alpha of the model's base sprite only. Paint/livery/decal/body-kit layers are excluded by construction. This preserves the exact-collision system while ensuring cosmetic purchases cannot alter gameplay.

## Review checklist

Before a ship can be enabled:

- base texture loads and is fully transparent outside the craft;
- nose points exactly up;
- no cropped pixels;
- visual footprint is deliberate;
- engine sockets align with every nozzle;
- tractor socket aligns with the recovery emitter;
- collision uses only the base model;
- all paint-mask channels align exactly;
- body-kit overlays do not change the base silhouette used for collision;
- desktop and mobile Web preview remain readable;
- content/core contracts are green.


## Propulsion trail customization

Ship propulsion presentation is composed from two existing save-facing cosmetic categories:

- `engine` selects the procedural trail behavior/style;
- `trail` selects the color palette used by that style.

The Fleet UI exposes both under one **Propulsion** editor. Keeping the two internal category IDs preserves existing saves while allowing style and color to combine independently.

Runtime composition is intentionally trail-only:

```
Ship engine_sockets[]
  -> PropulsionTrailRig per socket
     -> one to three world-space EngineTrail strands
```

`PropulsionTrailRig` contains no nozzle sprite, plume texture or propulsion particle emitter. This is deliberate: the ship can rotate while retaining inertial velocity, so a static nozzle flame can point somewhere different from the actual motion history and create contradictory feedback. The trail is generated from the real world-space socket history, so turning, coasting and boost remain visually truthful.

The eight authored styles must be structurally different, not simple width variants:

- Ion Stream — clean tapered core/ribbon;
- Plasma Bloom — wide animated multi-strand wave;
- Pulse Wave — repeated width pulses with visible gaps;
- Spark Jet — short broken jittering strands;
- Comet Ribbon — long tapered flowing tail;
- Shard Drive — angular segmented zig-zag;
- Nebula Mist — broad low-opacity multi-strand drift;
- Twin Helix — two animated sinusoidal strands in opposite phase.

Engine sockets may optionally author `fx_scale` and `rotation_degrees` for placement/preview alignment. These values affect presentation only. Propulsion cosmetics never modify collision, physics or ship stats.

Do not bake exhaust artwork into ship textures and do not add separate propulsion raster/SVG assets. New propulsion looks should be implemented through bounded procedural trail parameters and reusable renderer behavior.
