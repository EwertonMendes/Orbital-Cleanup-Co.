# AGENTS.md — Orbital Cleanup Co.

This file is an implementation contract for AI agents and human contributors. Read it before editing the repository.

## Product principle

Orbital Cleanup Co. is **a simple game sustained by intelligent infrastructure**, not a framework that tries to predict every future game. Prefer the simplest architecture that solves a real product need while remaining clean and extensible.

Priority order:

1. pleasant gameplay;
2. fast previews;
3. easy content creation;
4. progression;
5. retention;
6. monetization;
7. future reuse.

## Non-negotiable rules

1. **Never access a portal SDK from gameplay.** Godot gameplay may use only project-owned abstractions such as PlatformService, AdService and AnalyticsService.
2. **Never create sector-specific GDScript for a normal sector.** Standard sector variants must be data-driven.
3. Before introducing a system, search for an existing reusable abstraction and extend it when that is the cleaner design.
4. **Never add a third-party asset without recorded provenance and license.** Add files under `assets/third_party/<source>/` with `SOURCE.md` and `LICENSE.txt`, then update `docs/ASSETS.md`.
5. Do not use workarounds when the problem has a sound architectural solution. Fix root causes.
6. Do not duplicate UI patterns. Reuse components/themes where practical.
7. Do not hardcode economy values in UI or presentation scripts.
8. Do not hardcode authored content in gameplay scripts when it belongs in data.
9. Desktop and mobile are both product targets. Do not knowingly break one while fixing the other.
10. Every playable or visual change must provide a PR preview before merge.
11. **Never merge automatically.** Implement, validate, publish the preview, report it, and wait for explicit owner approval.
12. Keep requested changes in the same PR while they are part of the same feature/review cycle.
13. Do not edit unrelated files without a documented reason.
14. Do not turn the project into a large generic framework. Generalize only proven reusable needs.
15. Prefer straightforward, typed, readable GDScript and small focused modules.
16. Internationalized user-facing text must use translation keys. Supported launch locales are `en`, `pt_BR`, and `es_ES`.
17. GitHub Pages and PR previews always use `DebugWebProvider`; previews must never load a real ad SDK.
18. Do not hotlink runtime assets.
19. Do not introduce Git LFS unless repository size proves it is necessary and the owner approves it.
20. Save compatibility, once progression ships publicly, is a product contract. Use versioned schemas and migrations.
21. Avoid console spam. Emit explicit lifecycle/QA markers, not per-frame logs.
22. Curated procedural generation must preserve biome identity; randomness cannot replace authored constraints.
23. Measure browser/mobile performance before introducing chunk engines, complex shader stacks or other premature systems.

## Required development workflow

For each coherent feature:

1. start from the current default branch;
2. create a descriptive branch using `feat/`, `fix/`, `content/` or `chore/`;
3. implement only the coherent scope;
4. update relevant docs;
5. make CI green;
6. use the exact automated PR preview;
7. report test notes and known limitations;
8. wait for the owner to say **pode mergear** (or equivalent);
9. only then merge.

When fixing feedback, update the existing PR/branch. Do not create a replacement PR unless specifically requested.

## Definition of Done for playable PRs

- repository/content validation passes;
- Godot imports headlessly;
- Web export succeeds;
- browser smoke succeeds;
- no critical browser/page errors;
- desktop works;
- mobile landscape works when applicable;
- portrait degrades gracefully rather than breaking;
- user-visible behavior has adequate visual/audio feedback for its scope;
- docs are current;
- no obvious architectural debt was introduced.

## Architectural boundaries

`src/core/` is for capabilities that could plausibly be extracted later: app lifecycle, input, save, settings, audio, platform, build metadata, routing and utilities.

`src/game/` is exclusively Orbital Cleanup Co. domain logic: ship, salvage, sector, contracts, progression, economy, customization and discovery.

`src/ui/` contains screens, HUD, shared components and themes.

`src/debug/` contains development-only tools such as Sector Preview and save manipulation.

`web/` owns the JavaScript shell and provider adapters. Provider-specific JavaScript belongs here, never scattered through game code.

`content/` will own authored game definitions. Adding an ordinary sector must not require new GDScript.

## Provider contract

The eventual project-owned provider interface includes:

`initialize`, `get_provider_name`, `is_feature_available`, `gameplay_started`, `gameplay_stopped`, `show_interstitial`, `show_rewarded`, `track_event`, `pause_external_audio`, and `resume_external_audio`.

Every provider operation must tolerate missing features. Rewarded rewards are granted only after a provider confirms completion.

## Content rule

If creating a normal sector such as `mars_freight_17` requires adding a `.gd` file, stop: the architecture has failed. Use definitions, schemas, generic runtime classes and composition.

## External research

When adding/changing a portal integration, validate against current official provider documentation. SDKs change. Keep portal-specific details isolated so future SDK changes do not touch gameplay.
