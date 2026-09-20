# UI Guidelines — Orbital Cleanup Co.

The interface is part of the game's identity, not a debug surface around the game. Every screen should feel calm, legible, deliberate and visually coherent with the cozy orbital-cleanup fantasy.

## Information hierarchy

- Give each screen one obvious primary purpose.
- Prefer one dominant primary action. Secondary actions must look secondary.
- Show only information that helps the player make the current decision.
- Do not expose provider names, build SHAs, workflow IDs, debug state or implementation details in normal player-facing UI.
- Avoid decorative labels that repeat information already obvious from layout or iconography.
- Prefer short, scannable copy over paragraphs.

## Reusable visual system

Use the shared foundations before creating screen-local styling:

- `src/ui/themes/occ_palette.gd` for semantic colors;
- `src/ui/themes/occ_theme.tres` for standard controls;
- `src/ui/components/occ_panel_frame.tscn` for glass/metal card chrome;
- `src/ui/components/occ_action_button.gd` for primary/interactive button behavior.

If a reusable component already owns a pattern, do not copy its style into a new scene.

## Kenney asset usage

Kenney assets are raw material. They must be composed into Orbital Cleanup Co.'s own visual language.

- Use a curated subset only.
- Do not mix arbitrary color families from the pack on one screen.
- Prefer blue/cyan structure, mint success/ready states and amber emphasis.
- Do not use combat-oriented assets such as enemy ships, guns or lasers for this game.
- Keep background scenery subtle enough that controls and text remain the visual priority.
- Do not stretch a texture in ways that visibly destroy its intended borders; use NinePatchRect or appropriate stretch modes.

## Spacing and density

Preferred spacing steps are **6, 10, 14, 18, 24 and 32 px** at the 1280×720 reference viewport.

- Touch/click targets should normally be at least 44–46 px tall.
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

- Maintain strong text/background contrast.
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
