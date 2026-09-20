# Implementation Roadmap

The project is intentionally delivered as focused PRs with playable previews.

1. ✅ **Project Bootstrap + Web CI** — merged.
2. ✅ **Reusable Core + Visual Foundation** — merged.
3. 🚧 **Core Movement + Cozy Ship** — current PR: pointer/keyboard/touch steering, tuned acceleration/friction, visual tilt, engine trail, camera lead/shake, ambient training space and non-damaging bump behavior.
4. **Salvage Loop** — generic salvage, Tractor Beam, cargo, unload, Credits, HUD/VFX/SFX.
5. **Data-Driven Sector Engine** — definitions, schemas, validators, deterministic generation, biomes, tables, landmarks, modifiers, difficulty scaler.
6. **Contracts + Economy + Progression** — cleanup contract, payouts, Company XP/ranks, upgrades.
7. **Headquarters** — Contract Board, Upgrades, Career, Customization, Discovery.
8. **Customization** — hull, paint, trails, beam styles, persistence.
9. **Initial Content Pack** — four biomes, salvage, landmarks, modifiers, authored sector templates.
10. **Endless Contracts + Sector Preview** — deterministic endless generation, deep-link QA, debug generation UI.
11. **Platform Providers** — CrazyGames, GamePix, GameMonetize adapters and ad lifecycle.
12. **Polish + Retention** — discovery/rare feedback, satisfying VFX, scanner audio, transitions and balance.
13. **Release Pipeline** — provider ZIPs, manifest, checksums and manual release workflow.

Do not collapse these into one giant PR. Later milestones depend on approved foundations from earlier milestones.
