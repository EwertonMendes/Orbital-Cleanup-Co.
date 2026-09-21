# Implementation Roadmap

The project is intentionally delivered as focused PRs with playable previews.

1. ✅ **Project Bootstrap + Web CI** — merged.
2. ✅ **Reusable Core + Visual Foundation** — merged.
3. ✅ **Core Movement + Cozy Ship** — merged.
4. ✅ **Salvage Loop** — merged.
5. ✅ **Data-Driven Sector Engine** — merged.
6. ✅ **Contracts + Economy + Progression** — merged.
7. ✅ **Headquarters** — merged.
8. ✅ **Customization** — merged.
9. ✅ **Initial Content Pack** — merged.
10. ✅ **Endless Contracts + Sector Preview** — merged: deterministic endless generation, deep-link QA, debug generation UI.
11. ✅ **Platform Providers** — merged: CrazyGames, GamePix, GameMonetize adapters and normalized ad lifecycle.
12. ✅ **Polish + Retention** — merged: persistent discovery catalog, rarity feedback, shaders/post-processing, particles, procedural SFX, animated world/HQ motion and screen transitions.
12B. 🚧 **Contract Variety** — current PR: Cleanup, Full Cleanup, Recovery, Valuable Recovery and Priority Recovery across authored and endless sectors.
13. **Release Pipeline** — provider ZIPs, manifest, checksums and manual release workflow.

Do not collapse these into one giant PR. Later milestones depend on approved foundations from earlier milestones.

## Player-facing backlog

The original vertical-slice roadmap is substantially complete. Ongoing game-quality work is now tracked in `docs/PRODUCT_BACKLOG.md`, which intentionally contains only unfinished player-facing work.

Current PR: **Career & Reward Loop — Contract Debrief**. Completed contracts now route through a dedicated payout / XP / promotion / discovery result screen before returning to Headquarters.
