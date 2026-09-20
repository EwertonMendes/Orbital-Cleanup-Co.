# AGENTS.md — Orbital Cleanup Co.

This file is an implementation contract for AI agents and human contributors. Read it before editing the repository.

## Product principle

Orbital Cleanup Co. is **a simple game sustained by intelligent infrastructure**, not a framework that tries to predict every future game. Prefer the simplest architecture that solves a real product need while remaining clean and extensible.

Priority order:

1. pleasant gameplay;
2. visual clarity and feel;
3. fast previews;
4. easy content creation;
5. progression;
6. retention;
7. monetization;
8. future reuse.

## Non-negotiable rules

1. **Never access a portal SDK from gameplay.** Godot code may use only project-owned abstractions such as `PlatformService`.
2. **Never create sector-specific GDScript for a normal sector.** Standard sector variants must be data-driven.
3. Before introducing a system, search for an existing reusable abstraction and extend it when that is the cleaner design.
4. **Never add a third-party asset without recorded provenance and license.** Add files under `assets/third_party/<source>/` with `SOURCE.md` and `LICENSE.txt`, then update `docs/ASSETS.md`.
5. Do not use workarounds when the problem has a sound architectural solution. Fix root causes.
6. **UI is a product feature.** Do not accept technically functional but visually careless screens.
7. Reuse `src/ui/themes/` and `src/ui/components/` before creating screen-local styles. Do not duplicate an existing component pattern.
8. Every player-facing screen must have a clear information hierarchy and primary purpose. Do not expose build SHA, provider, workflow/debug state or implementation metadata outside explicit debug tooling.
9. Permanent user-facing text must use translation keys. Supported launch locales are `en`, `pt_BR`, and `es_ES`.
10. Do not hardcode economy values in presentation scripts once the corresponding game data exists.
11. Do not hardcode authored content in gameplay scripts when it belongs in data.
12. Desktop and mobile are both product targets. Do not knowingly break one while fixing the other.
13. Every playable or visual change must provide a PR preview before merge.
14. **Never merge automatically.** Implement, validate, publish the preview, report it, and wait for explicit owner approval.
15. Keep requested changes in the same PR while they are part of the same feature/review cycle.
16. Do not edit unrelated files without a documented reason.
17. Do not turn the project into a large generic framework. Generalize only proven reusable needs.
18. Prefer straightforward, typed, readable GDScript and small focused modules.
19. GitHub Pages and PR previews always use `DebugWebProvider`; previews must never load a real ad SDK.
20. Do not hotlink runtime assets.
21. Do not introduce Git LFS unless measured repository/build size justifies it and the owner approves it.
22. Save compatibility, once progression ships publicly, is a product contract. Use versioned schemas and migrations.
23. Avoid console spam. Emit explicit lifecycle/QA markers, not per-frame logs.
24. Curated procedural generation must preserve biome identity; randomness cannot replace authored constraints.
25. Measure browser/mobile performance before introducing chunk engines, complex shader stacks or other premature systems.
26. Important runtime/service/component assumptions must be backed by executable structural assertions when practical. Prefer a failing CI contract to a comment describing what “should” exist.

## UI implementation contract

Read `docs/UI_GUIDELINES.md` before player-facing UI work.

In particular:

- one obvious purpose per screen;
- normally one dominant CTA;
- no information merely because it is available;
- touch/click targets normally at least 44–46 px;
- visible focus for keyboard/gamepad;
- responsive Containers/anchors rather than absolute primary layout;
- shared palette/theme/components before custom styles;
- Kenney art is raw material, not the finished OCC identity;
- generated desktop/mobile screenshots and the exact playable preview are part of visual review.

## Required development workflow

For each coherent feature:

1. start from the current default branch;
2. create a descriptive branch using `feat/`, `fix/`, `content/` or `chore/`;
3. implement only the coherent scope;
4. update relevant docs;
5. make repository validation and Godot contract tests green;
6. make Web build/browser smoke green;
7. use the exact automated PR preview;
8. report test notes and known limitations;
9. wait for the owner to say **pode mergear** (or equivalent);
10. only then merge.

When fixing feedback, update the existing PR/branch. Do not create a replacement PR unless specifically requested.

## Definition of Done for playable PRs

- repository/content/asset-provenance validation passes;
- Godot imports headlessly;
- executable structural contract tests pass;
- Web export succeeds;
- browser smoke succeeds;
- no critical browser/page/resource errors;
- desktop works;
- mobile landscape works when applicable;
- portrait degrades gracefully rather than breaking;
- player-facing UI is visually deliberate and not cluttered;
- relevant controls provide adequate visual/audio feedback for their scope;
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

The project-owned provider surface includes:

`initialize`, `get_provider_name`, `is_feature_available`, `gameplay_started`, `gameplay_stopped`, `show_interstitial`, `show_rewarded`, `track_event`, `pause_external_audio`, and `resume_external_audio`.

Every provider operation must tolerate missing features. Rewarded rewards are granted only after a provider confirms completion.

## Content rule

If creating a normal sector such as `mars_freight_17` requires adding a `.gd` file, stop: the architecture has failed. Use definitions, schemas, generic runtime classes and composition.

## External research

When adding/changing a portal integration or third-party source, validate against current official documentation/source pages. Keep external-provider details isolated so future changes do not touch gameplay.
