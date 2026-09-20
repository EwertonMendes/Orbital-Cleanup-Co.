# Orbital Cleanup Co.

**Orbital Cleanup Co.** is a cozy 2D space-cleanup game built with Godot and designed first for HTML5 distribution.

> Keeping the galaxy tidy, one orbit at a time.

The project is intentionally developed **GitHub-first**. Normal development should not require a local Godot, Node, export-template, or browser-testing environment.

## Development flow

`branch → Pull Request → CI → Web build → playable preview → approval → merge → production`

Playable or visual work remains in its PR until explicitly approved. The AI must never merge a feature automatically.

## Current milestone

**PR 1 — Project Bootstrap + Web CI**

The bootstrap establishes:

- Godot 4.7.2 with GL Compatibility and single-threaded Web export;
- 1280×720 reference viewport with responsive canvas-item stretching;
- internationalization baseline: English (US), Portuguese (Brazil), Spanish (Spain);
- custom Web shell;
- isolated `DebugWebProvider` with no real advertising network;
- build metadata exposed to the runtime;
- headless import/export validation;
- browser smoke on desktop, mobile landscape and mobile portrait;
- GitHub Pages production + preserved `/pr-N/` previews;
- one self-updating playable-preview comment per PR;
- project rules and architecture documentation.

Gameplay starts in later focused PRs after this foundation is approved.

## Repository map

```text
assets/
  branding/
  third_party/          # added only with provenance + license
content/                 # data-driven game content (introduced with Sector Engine)
docs/
i18n/
src/
  core/
  game/
  ui/
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

1. lightweight repository validation;
2. Godot 4.7.2 headless import;
3. Web export;
4. browser smoke in Chrome;
5. QA screenshots;
6. GitHub Pages preview using the `debug` provider.

The production Pages root is only updated from the repository default branch.

See [docs/CI_CD.md](docs/CI_CD.md) for details.

## Project documentation

- [Game design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Content authoring](docs/CONTENT_AUTHORING.md)
- [Platform integration](docs/PLATFORM_INTEGRATION.md)
- [CI/CD](docs/CI_CD.md)
- [Release strategy](docs/RELEASES.md)
- [Asset provenance](docs/ASSETS.md)
- [Implementation roadmap](docs/ROADMAP.md)

AI contributors must read [AGENTS.md](AGENTS.md) before making changes.
