# Game Design — Orbital Cleanup Co.

## Fantasy and tone

The player is an employee of **Orbital Cleanup Co.**, a company contracted to clean and recover orbital debris around the galaxy. The tone is friendly, modern, colorful and lightly corporate. It is not a shooter, military game, dark survival game, realistic simulator or retro pixel-art title.

There is no combat, enemy, death or failure-by-destruction. Challenge comes from movement, efficient routing, cargo management, environmental hazards, contract targets and optimization.

## Core interaction

Desktop movement is primarily pointer-directed: the cursor defines direction and distance from the ship influences desired acceleration, with a center deadzone and smooth deceleration. WASD and arrows are an alternative.

Mobile uses one-finger drag/hold direction input. A mandatory on-screen joystick should not occupy the playfield. Landscape is preferred; portrait must remain functional.

The most important early feel target is simply moving the ship. Movement should be enjoyable before deeper systems exist.

## Automatic collection

Recoverable objects are collected without click spam:

1. object enters Tractor Beam range;
2. detection feedback appears;
3. beam activates automatically;
4. target is pulled;
5. collection progresses;
6. salvage enters cargo;
7. credits/salvage/discovery bookkeeping updates.

Larger objects pull more slowly, create stronger feedback, may add light drag and are worth more. Later upgrades may support multiple simultaneous targets.

## Environmental gameplay

Non-lethal environmental pressure includes asteroids, gravity regions, slowing nebulas, currents, large wrecks, low visibility and magnetic zones. Collisions may rotate the ship slightly, reduce speed briefly, spawn particles, play a soft impact and apply modest screen shake. The tone remains cozy.

## Contracts

Each playable sector is presented as a company contract with target cleanliness, base pay, perfect-cleanup bonus, optional rare-salvage authorization and contextual modifiers.

The player may complete the minimum target and leave, or continue to 100% for **Perfect Cleanup**.

Primary contract archetypes planned:

- Standard Cleanup;
- Full Cleanup;
- Recovery;
- Valuable Recovery;
- Priority Object.

The MVP should implement only what is required for the vertical slice and keep the contract runtime extensible.

## Main loop

`Headquarters → select contract → deploy → explore/collect → cargo unload → target achieved → optional 100% → return → payout → Company XP → upgrades/customization → next contract`.

Headquarters is a UI space, not a walkable map.

## Headquarters

Headquarters is the between-contract decision space and remains interface-only rather than a walkable map.

The vertical-slice HQ is organized into five focused work areas:

- Contract Board;
- Equipment Upgrades;
- Career;
- Ship;
- Discovery.

Contract Board is the default view and the only place with the deploy CTA. Other sections exist to answer a specific player question instead of repeating the same information across multiple screens.

## Economy and progression

Launch economy uses one currency: **Credits**. Sources include base contract pay, salvage, rare objects, Perfect Cleanup and specific bonuses.

Permanent upgrade families:

- Tractor Beam range / later multi-target;
- Collection Speed;
- Engine acceleration / top speed;
- Cargo capacity;
- Scanner detection / rare guidance;
- Recycler value bonuses.

Values are data-driven, never presentation hardcodes.

Company XP progresses through career ranks approximately:

`Trainee → Junior Cleaner → Orbital Cleaner → Senior Cleaner → Sector Specialist → Deep Space Operator`.

Ranks unlock regions, contracts, equipment, cosmetics, modifiers and higher rarity content.

## Customization

Cosmetics never alter gameplay. Initial families:

- Hull;
- Paint via shader/modulate where possible;
- Engine Trail;
- Tractor Beam style.

Avoid duplicate sprites solely for recolors when shaders/modulation solve the problem.

## Discovery collection

Special salvage types enter a catalog on first recovery and trigger **NEW DISCOVERY**. Examples include Lost Probe, Broken Satellite, Cargo Capsule, Research Module, Solar Crystal, Explorer Core and Ancient Module.

## Sector philosophy

A normal sector is data, not a dedicated Godot scene. One generic **Sector Engine** loads a biome and sector definition, then composes curated procedural content.

A sector should communicate identity through at least three strong elements:

1. recognizable biome;
2. landmark or distinct composition;
3. meaningful contract/modifier.

Random rocks on a recolored background are not enough.

## Curated procedural generation

Biomes constrain allowed visuals, salvage, obstacles, landmarks, ambience and modifiers. Seeds change layout while the authored biome kit preserves identity.

Endless contracts are deterministic by seed and scale through centralized curves rather than level-specific conditionals. Contract 10,000 must remain generatable.

## Initial content target

After the vertical slice:

- 4 biomes: Earth Orbit, Lunar Belt, Mars Freight Route, Blue Nebula;
- 6+ landmarks;
- 20+ salvage definitions;
- 5 contract configurations;
- 6–8 modifiers;
- 10–16 authored sector templates;
- endless deterministic generator.

## First vertical slice

One ship, one biome/sector, Tractor Beam, five salvage types, cargo, unload point, cleanup percentage, one contract, Credits, three upgrades, Web build and mobile support.

Do not scale content before this loop feels good.

## Vertical-slice progression implementation

The current vertical slice now implements the first complete progression loop:

```text
deploy → recover salvage → reach cleanup target → optional Perfect Cleanup
→ return → Credits + Company XP → buy ship upgrade → deploy again
```

The initial contract target is 70%. Reaching the target allows the player to finish the contract; continuing to 100% grants the configured Perfect Cleanup bonus.

The first functional upgrades are Tractor Beam range, collection speed and cargo capacity. Their prices/effects and all career rank thresholds are authored in progression content rather than UI code.

Aborting before the cleanup target returns to Operations without contract payout.

## Current customization slice

The Headquarters Ship workspace now allows cosmetic loadout selection with persistent save support.

Current categories:

- Hull — Pioneer-01 is the currently curated model;
- Paint — Company Blue, Service Mint, Safety Amber;
- Engine Trail — Ion Cyan, Mint Stream, Amber Comet;
- Tractor Beam — Standard Cyan, Mint Recovery, Amber Precision.

Starting-rank alternatives are immediately selectable. Amber variants unlock at Junior Cleaner. Cosmetics never alter movement, cargo, collection speed, beam range or economy.

Paint is applied by shader to the colored hull regions instead of shipping duplicate recolored sprites. Additional hull models can be added later through cosmetic content once their binary assets are imported through the normal provenance-controlled asset workflow.

## Current polish and retention slice

The current polish milestone turns presentation into reusable gameplay systems rather than one-off scene decoration.

- rare and epic salvage are special Discoveries on first recovery and persist by salvage ID;
- Discovery presentation resolves current content metadata instead of copying stale names/values into the save file;
- recovery, impact, unload, contract-target and Perfect Cleanup events drive centralized visual/audio feedback;
- sector ambience uses deterministic lightweight motion so authored and endless sectors share the same presentation path;
- hazards may visually tumble and landmarks may drift without moving their collision/gameplay anchors;
- the world post-process is deliberately below the HUD CanvasLayer so UI readability is not color-graded;
- compact Web/mobile viewports use a reduced post-processing profile automatically;
- screen transitions belong to SceneRouter, not individual screens.

The visual pass must not turn the game into a combat spectacle. Effects should reward cleanup and navigation while preserving the cozy corporate-space tone.

## Living biome implementation

Biome identity is now both mechanical and visual. Normal sector code must not branch on a specific biome ID to decide gameplay rules. Instead, biome JSON authors reusable environmental volumes and a visual profile; the generic Sector Generator and Environment Runtime interpret those definitions.

Current biome roles:

- **Earth Orbit** — neutral baseline. Navigation, scanner and Tractor Beam operate normally so early contracts remain clear and onboarding-friendly.
- **Lunar Belt** — gravity wells gently influence ship/salvage trajectories. A long safe corridor is generated through the depot and collision hazards are explicitly excluded from that lane.
- **Mars Freight Route** — directional drift currents push the ship and loose salvage. The biome also applies a higher salvage-mass multiplier so freight recovery feels materially heavier.
- **Blue Nebula** — low-visibility pockets alter world post-processing, scanner interference reduces effective detection range, Tractor Beam distortion reduces pull/collection efficiency, and magnetic zones influence loose salvage more strongly than the ship.

Environmental pressure is deliberately bounded. Fields use smooth falloff, never destroy the ship, never fully disable scanner/Tractor Beam and cannot overpower normal steering. Their job is route planning and feel, not punishment.

Visual identity uses project-owned editable SVG planets under `assets/original/planets/`, a shared animated surface/atmosphere shader, camera-relative parallax, biome-specific ambient motion and distant traffic. HUD text identifies the dominant local environmental effect while the world itself provides matching field visuals.


## Memorable orbital landmark implementation

Large structures are now part of navigation, not just scenery.

The launch landmark family uses eight project-owned silhouettes: service satellite, cargo waystation, relay tower, lunar mining rig, fractured moonlet, communications array, Blue Nebula research outpost and a large derelict explorer wreck. Their shapes are intentionally much larger and more recognizable than salvage.

Landmarks remain data-driven. Content authors choose placement range, navigation clearance, circle/box collision geometry, restrained motion and visual asset through JSON. The generic Sector Engine places them deterministically.

Their `reserved_radius` is an actual composition rule: normal salvage and collision hazards are generated outside the structure's protected footprint. The ship can collide with the authored structure itself using the existing non-lethal bump response, which creates corridors, detours and recognizable navigation anchors without introducing damage or combat.

Major orbital structures should continue to be authored as distinct silhouettes rather than enlarged small props. A new normal sector must still require data only, not landmark-specific GDScript.


## Cargo depot navigation

The cargo depot is the ship's deployment/home point and must remain easy to find in every authored and Endless sector without turning the flight HUD into a minimap.

Navigation uses two complementary cues:

- the world depot has a restrained animated beacon and persistent local label;
- when the depot leaves the usable viewport, a small edge guide points toward its real world position and displays approximate distance.

The guide is generic: Flight binds it directly to the current sector's `UnloadDepot` node after the sector's data-driven depot position is applied. There are no biome IDs, sector IDs or hardcoded depot coordinates in normal gameplay.

The edge guide projects the real depot world position through the active viewport canvas transform, so it stays correct with camera movement and responsive layouts. It hides automatically when the depot is visible or the ship is already nearby.

Cargo state changes emphasis but not layout: normal travel uses calm cyan guidance; a full cargo hold promotes the same beacon/guide to amber. The guide updates at 30 Hz and the world beacon redraws at 20 Hz to preserve Web/mobile frame pacing.
