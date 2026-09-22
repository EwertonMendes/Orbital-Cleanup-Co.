# UI Guidelines — Orbital Cleanup Co.

The interface is part of the game's identity, not a debug surface around the game. Every screen should feel calm, legible, deliberate and visually coherent with the cozy orbital-cleanup fantasy.

## Information hierarchy

- Give each screen one obvious primary purpose.
- Prefer one dominant primary action. Secondary actions must look secondary.
- Show only information that helps the player make the current decision.
- Do not show future locked contracts or cosmetic choices in routine browsing. Endless and Discovery navigation remain absent until unlocked.
- Language and master-audio controls belong in Settings, not in the persistent Operations header.
- Career owns rank/XP/next-unlock information; Contracts should not repeat progression bookkeeping.
- Do not expose provider names, build SHAs, workflow IDs, debug state or implementation details in normal player-facing UI.
- Avoid decorative labels that repeat information already obvious from layout or iconography.
- Prefer short, scannable copy over paragraphs.

## Reusable visual system

Use the shared foundations before creating screen-local styling:

- `src/ui/themes/occ_operations_theme.tres` for the light physical Operations console and its Kenney button/panel assets;
- `src/ui/themes/occ_flight_hud_theme.tres` for compact dark in-flight cards and actions that preserve readability over moving space scenery;
- `src/ui/themes/occ_theme.tres` is legacy-only and must not be used by player-facing screens;
- `src/ui/themes/occ_cursor_skin.gd` for the original Kenney desktop cursor states;
- screen layouts built from Containers, with `StyleBoxTexture`/NinePatch only where the source asset is designed to scale.

If a reusable component already owns a pattern, do not copy its style into a new scene.

## Player-facing UI contract

All player-facing UI must use the current Orbital Cleanup Co. visual language. This includes Operations, in-flight HUD, Contract Debrief, bootstrap/loading surfaces, settings, transient travel/loading panels and future menus.

- Do not introduce a new player screen on `occ_theme.tres` or with screen-local generic `StyleBoxFlat` chrome.
- Light menu/report surfaces use `occ_operations_theme.tres`; gameplay overlays use `occ_flight_hud_theme.tres`.
- Loading and transition UI is still product UI: it must use the same typography, Kenney-derived chrome, spacing and contrast standards.
- Semantic action state is consistent everywhere: destructive/abort is red, successful completion is green, primary forward actions are yellow, the in-flight Operations/open-console action is blue, and neutral utilities remain dark/outlined.
- A new UI surface is not complete until desktop, landscape-mobile and portrait-mobile smoke screenshots show no clipping, unreadable contrast or fallback styling.

## Floating gameplay interfaces

The ship and live world are the default presentation layer. Between-contract decisions should normally appear over gameplay instead of replacing it with a full-screen lobby.

- Operations uses a centered floating surface with generous world visibility around it on desktop/landscape.
- A restrained scrim may reduce visual competition but must not read as a scene cut or black loading screen.
- Opening an overlay suspends ship steering deliberately while ambient world motion remains alive.
- Contract deployment and return transitions must visually originate from the ship; do not hide routing behind an abrupt screen fade.
- Compact/mobile layouts may use more of the viewport when required for legibility, but must preserve the same hierarchy and close action.
- Reuse the existing Operations screen in embedded mode rather than maintaining separate full-screen and in-flight copies of the same product UI.

## Gameplay world readability

World objects use a semantic visual language that must remain consistent across every biome:

- **recoverable salvage** uses cool recovery brackets/halo plus a rarity pip;
- **collision hazards** use segmented warm/amber hazard rings and a darker neutral body treatment;
- **landmarks** use broad, low-contrast environmental arcs and must read as scenery rather than pickups;
- the cargo depot uses mint/green recovery language and is visually distinct from both salvage and hazards.

Shape and motion carry the first distinction; color reinforces it. Important gameplay categories must never rely on color alone.

Meteor/asteroid silhouettes are reserved for hazards. Salvage definitions must not use meteor sprites, even for items named scrap, rock, shielding or regolith. CI enforces this rule in `tools/validate_content.py`.

New categories should extend `WorldVisualLanguage` rather than introducing screen-local colors or one-off object effects. New salvage automatically inherits the shared `SalvageMarker`; new hazards and landmarks inherit their corresponding marker components.

Salvage identity is data-driven. Each definition owns an authored silhouette plus a compact visual profile for motion and ambient effect. Common items can stay restrained, while rare/epic items must communicate rarity through shape, motion and energy treatment before the player reads a label. Do not create one scene or one GDScript class per salvage item.

## Typography

Typography is a semantic system, not one font stretched across every piece of UI.

- **Neuropol** is the display/game-identity face for branding, major titles, section headings, tabs and important rarity labels.
- **Inter** is the reading face for descriptions, utility labels and longer copy. Interactive button labels use Neuropol so actions consistently carry the game identity.
- **JetBrains Mono** is reserved for telemetry: credits, XP, numeric values, progress metadata and compact system-like readouts.
- Font selection belongs in shared Theme type variations such as `DisplayLabel`, `UiBody`, `TelemetryLabel`, `PrimaryButton` and `TabButton`. Screens must not assign font files directly.
- Neuropol is intentionally concentrated in branding, headings and interactive controls. Large amounts of body copy remain in Inter so the interface feels like a game without sacrificing readability.

Oxanium is not part of the Orbital Cleanup Co. typography system.

## Kenney UI Pack - Sci-Fi usage

Operations deliberately uses the **original Kenney UI Pack - Sci-Fi visual language** rather than redrawing it as generic Godot rectangles.

- Keep the source pixels, colors, bevels, screws and highlights intact. Do not tint, recolor, paint over, blur or shader-modulate Kenney UI textures.
- Use the pack's `Double` assets for resizable console chrome and preserve their corner geometry through `StyleBoxTexture` or `NinePatchRect`.
- Use 9-slice scaling only on textures intended to form resizable buttons/panels. Decorative or cursor assets render at their native proportions.
- Never animate scale or height on Kenney panels/buttons. Control geometry must remain completely stable; menu-content transitions may slide the content panel inside a clipped viewport without moving the navigation buttons themselves.
- Ordinary Operations buttons use a clean dark rounded Kenney bar with centered Neuropol labels. Colored blade/header overlays and screw-heavy button textures are not used for routine actions.
- The active navigation tab uses the original full yellow Kenney bar with dark text and a very slow subtle glow pulse; inactive tabs remain dark.
- Tab changes use a clean directional slide: the old content moves out and the new content moves in inside the clipped content area. Do not add warp streaks or blue transition particles over menus.
- The live-flight HUD deliberately uses a darker companion theme for contrast over gameplay, while keeping the same fonts, spacing discipline and Kenney-derived action language. The current-flight and cargo cards are **asset-only dark-mode surfaces**: the rounded Kenney glass panel is rendered with a near-black treatment as one complete frame/background, with no notched/octagonal silhouette, extra Godot-drawn rectangle or second white/cyan border behind it. Content stays inside the asset's safe center with white/light typography; cyan/mint/amber are reserved for meaningful status and progress accents. The Operations action uses the original full blue Kenney bar so it reads as clickable as clearly as red Abort Contract and green Complete Contract.
- The pack's own cursor art is used for arrow, pointing and pressed states on desktop.
- Kenney Interface Sounds provide restrained hover, click and back cues through the centralized AudioService.
- Operations should read like a physical game console, not a corporate dashboard: one focused content area, compact vertical navigation, settings in a modal, and progression content revealed only when relevant.
- Do not use combat-oriented assets such as enemy ships, guns or lasers for this game.

## Raster quality

The gameplay ship is a small raster source and must not be magnified casually.

- Gameplay ship sprite renders at native scale.
- Camera zoom stays at 1× for the current asset set.
- Continuous steering feedback must not deform the sprite with skew/scale animation.
- Physics interpolation is required for smooth Web movement.
- UI ship previews may scale only inside an aspect-preserving TextureRect and should remain moderate in size.
- Use linear filtering for rotated non-pixel-art sprites.

## Spacing and density

Preferred spacing steps are **6, 10, 14, 18, 24 and 32 px** at the 1280×720 reference viewport.

- Touch/click targets should normally be at least 44–48 px tall. Standard Operations actions use a 48 px native control height to avoid texture distortion.
- Cards need enough internal breathing room that text does not touch their chrome.
- Dense stat rows should be reserved for information that genuinely benefits from side-by-side comparison.
- A smaller screen may stack sections rather than squeezing them.

## Responsive behavior

The baseline viewport is 1280×720, but the UI must remain usable on Web/mobile.

- Desktop and landscape: favor side-by-side structure when it improves comparison.
- Below approximately 820 px width: major panels may stack vertically.
- Portrait must degrade gracefully and remain readable even when landscape is preferred.
- Avoid absolute positions for primary layout. Use Containers, anchors and margins.
- Decorative art may use anchors/offsets, but cannot determine the usability of controls.

## Accessibility and interaction

- Maintain strong text/background contrast. Muted copy on the light Operations board must still be dark enough to read without relying on opacity.
- Keyboard/gamepad focus must be visible.
- Interactive elements should use appropriate pointer cursors on desktop.
- Do not rely on color alone for important state.
- All permanent player-facing copy must use localization keys for `en`, `pt_BR` and `es_ES`.

## Validation

Visual work is not done when it merely compiles.

- Core scene/component contracts are asserted in `tools/validate_core_contracts.gd`.
- Browser smoke must pass.
- Desktop, landscape-mobile and portrait-mobile screenshots must be reviewed.
- Prefer structural assertions over brittle pixel-perfect snapshot tests.
- A visual PR must provide its exact playable preview before merge.

## World polish boundary

World-space polish and UI chrome are separate systems.

- Full-screen grading/post-processing belongs below the HUD CanvasLayer. Do not post-process HUD text or controls.
- Use subtle vignette, restrained glow and minimal chromatic separation; readability wins over spectacle.
- Rare/epic salvage can use animated energy treatment, but collision hazards keep the exclusive warm segmented-ring language.
- Particle bursts are event-driven and short-lived. Avoid permanent high-count emitters on every salvage object.
- Environmental motion must be visual-only unless a gameplay mechanic explicitly requires moving collision geometry.
- Web/mobile performance is a first-class constraint: prefer CPUParticles2D for small portable bursts and reduce screen-effect strength on compact viewports.
