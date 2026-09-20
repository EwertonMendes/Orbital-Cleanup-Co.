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

