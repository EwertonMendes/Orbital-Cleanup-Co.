# Orbital Cleanup Co. — Product Backlog

This file is the living list of **player-facing work that is still missing** before Orbital Cleanup Co. feels like a polished, replayable game.

## Maintenance rule

- Keep only unfinished work here.
- When a backlog item is fully implemented and merged, remove it instead of turning this file into a changelog.
- Platform SDK integration, portal submission and release packaging are intentionally out of scope for this list.
- Architecture/refactor tasks belong here only when they directly improve player experience.

## Remaining priorities

### 1. Career progression and region unlocks

Turn Company XP and ranks into a visible progression path instead of letting every authored sector be available immediately.

- Gate authored regions/contracts by career rank.
- Start the player in Earth Orbit and progressively unlock Lunar Belt, Mars Freight Route and Blue Nebula.
- Show locked contracts with the exact rank/XP requirement.
- Show "next unlock" progress in Headquarters.
- Allow ranks to unlock contract pools, modifiers, cosmetics and future equipment cleanly through data.
- Preserve Endless Contracts as a late/progressive system instead of an always-equivalent alternative.

### 2. Biome-specific gameplay mechanics

Make each region change how the player flies and plans routes, not only palette, salvage tables and obstacle density.

- Earth Orbit: neutral baseline and onboarding-friendly navigation.
- Lunar Belt: gravity regions, narrow safe corridors and stronger inertial routing.
- Mars Freight Route: directional solar/dust currents and heavier recovery routes.
- Blue Nebula: low-visibility pockets, scanner interference and Tractor Beam disturbances.
- Keep pressure non-lethal and cozy.
- Author mechanics through reusable data-driven environmental volumes rather than sector-specific code.

### 3. Music and environmental soundscape

Add a real audio identity on top of the existing procedural gameplay SFX.

- Headquarters music/ambience.
- Distinct ambient loop for each biome.
- Depot/industrial ambience.
- Rare/Epic discovery musical sting.
- Rank-up / major unlock cue.
- Separate music and SFX volume controls.
- Record asset provenance and license for every external audio file.

### 4. Stronger visual identity and world silhouettes

Reduce the remaining "asset-pack prototype" feeling.

- Give Rare/Epic salvage more unique silhouettes instead of reusing the same satellite families.
- Add large biome-specific background structures: stations, cargo ships, solar arrays, ruins, moons and distant traffic.
- Add parallax/depth layers where they improve scale.
- Improve landmark uniqueness and composition.
- Keep recoverable salvage, hazards and scenery semantically distinct.

### 5. Expand upgrades and ship customization

Give Credits and career progression more meaningful long-term sinks.

- Engine acceleration / top-speed upgrades.
- Scanner guidance / rare-object assistance.
- Recycler / salvage-value upgrades.
- Multi-target Tractor Beam as a high-tier upgrade.
- Add multiple visually distinct hulls.
- Expand rank-unlocked paint, trail and beam families.
- Keep cosmetics gameplay-neutral.

### 6. Onboarding, pause/settings and complete gamepad support

Make the game understandable and comfortable without prior explanation.

- Contextual first-contract onboarding: move → collect → cargo full → unload → objective → finish.
- Persist tutorial completion so prompts do not repeat unnecessarily.
- Proper pause menu with Resume, Audio, Language, Controls, Restart Contract and Return to HQ.
- Full gamepad action mapping, focus navigation and prompts.
- Music/SFX settings plus accessibility-oriented options where useful.
- Validate keyboard/mouse, touch and gamepad separately.

### 7. Mastery, commendations and replay goals

Reward players who want to optimize without adding combat or punitive failure.

- Optional Company Commendations such as Perfect Cleanup, No Collision, One-Trip Recovery and Cargo Efficiency.
- Persist best sector records.
- Surface personal bests in Headquarters.
- Use commendations to unlock cosmetics or small non-power rewards where appropriate.
- Add long-term goals without turning the cozy loop into a high-pressure score attack.

### 8. Front-door presentation and Discovery depth

Improve first impression and collection motivation.

- Replace the direct-to-HQ first impression with a concise branded start/continue flow.
- Keep startup fast; avoid long unskippable intros.
- Expand Discovery with found/total progress, unknown silhouettes, origin biome and short corporate lore.
- Add collection completion milestones/rewards.
- Ensure returning players can reach gameplay with minimal friction.
