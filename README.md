# Orbital Cleanup Co.

**Orbital Cleanup Co.** is a cozy 2D space-cleanup game built with Godot and designed first for HTML5 distribution.

> Keeping the galaxy tidy, one orbit at a time.

The project is intentionally developed **GitHub-first**. Normal development should not require a local Godot, Node, export-template, or browser-testing environment.

## Development flow

`branch → Pull Request → CI → Web build → playable preview → approval → merge → production`

Playable or visual work remains in its PR until explicitly approved. The AI must never merge a feature automatically.

## Current milestone

**Living Biomes**

The four launch regions now have distinct data-driven environmental gameplay and visual identities instead of behaving like recolored debris fields.

- Earth Orbit remains the clear, stable baseline with active orbital traffic and an animated Earth backdrop.
- Lunar Belt adds gravity wells and an authored safe corridor that the obstacle generator keeps clear.
- Mars Freight Route adds directional solar/dust currents and heavier salvage recovery.
- Blue Nebula adds low-visibility pockets, scanner interference, Tractor Beam distortion and magnetic fields.

All biome effects run through reusable environmental fields, while project-owned vector planets, parallax, animated atmosphere, ambient motion and distant traffic keep each location visibly alive.

The remaining player-facing work is tracked in `docs/PRODUCT_BACKLOG.md`.

## Visual direction

The game should feel friendly, modern, clean and lightly corporate rather than military or cluttered. Third-party packs are source material; Orbital Cleanup Co. owns the composition, hierarchy, palette and interaction language.

See [UI Guidelines](docs/UI_GUIDELINES.md).

## Repository map

```text
assets/
  branding/
  third_party/          # curated files + SOURCE.md + LICENSE.txt
content/                 # data-driven game content (introduced with Sector Engine)
docs/
i18n/
src/
  core/
  game/
  ui/
    components/
    screens/
    themes/
  debug/
tools/
web/
  platform/
  shell/
.github/
  scripts/
  workflows/
```

## CI

Every PR targeting the default branch runs:

1. repository/localization/asset-provenance validation;
2. Godot 4.7.2 headless import;
3. real Godot core/UI contract assertions;
4. Web export;
5. browser smoke in Chrome;
6. desktop/mobile QA screenshots;
7. GitHub Pages preview using the `debug` provider.

The production Pages root is only updated from the repository default branch.

See [CI/CD](docs/CI_CD.md).

## Project documentation

- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UI guidelines](docs/UI_GUIDELINES.md)
- [Content authoring](docs/CONTENT_AUTHORING.md)
- [Platform integration](docs/PLATFORM_INTEGRATION.md)
- [CI/CD](docs/CI_CD.md)
- [Release strategy](docs/RELEASES.md)
- [Asset provenance](docs/ASSETS.md)
- [Implementation roadmap](docs/ROADMAP.md)

AI contributors must read [AGENTS.md](AGENTS.md) before making changes.
