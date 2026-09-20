# Platform Integration

## Boundary

Portal SDKs are adapters, never gameplay dependencies.

Godot talks only to project-owned services:

- `PlatformService` owns the JavaScript bridge and normalized provider events.
- `AdService` owns ad policy, serialization, game pause/resume and audio pause/resume.
- gameplay/UI code never references CrazyGames, GamePix or GameMonetize names or SDK methods.
- JavaScript owns provider-specific SDK loading and API differences.

`tools/validate_bootstrap.py` rejects portal identifiers leaking into Godot scenes/resources/scripts.

## Runtime architecture

```text
Godot gameplay
    ↓
AdService / PlatformService
    ↓
window.OCCPlatform
    ↓
provider adapter
    ↓
portal SDK
```

The Web shell waits for `window.OCCPlatformReady` before starting the Godot engine. Godot therefore binds to an already-resolved provider and does not initialize the SDK a second time.

All adapters normalize ad lifecycle to two events:

- `ad_started` — the portal has begun an ad break;
- `ad_result` — the request finished, failed, was unavailable or was not shown.

Each request has a stable `requestId`, `kind`, `placement`, completion state and rewarded state.

## Providers

### Debug

Used by GitHub Pages and PR previews only.

- no network ad SDK;
- simulates interstitial and rewarded ads;
- exercises the exact same Godot pause/audio lifecycle as a real provider;
- never acts as a silent production fallback.

Unknown providers degrade to `NullProvider`, where portal features are unavailable and gameplay continues normally.

### CrazyGames

Official HTML5 SDK v3:

- SDK: `https://sdk.crazygames.com/crazygames-sdk-v3.js`
- docs: `https://docs.crazygames.com/sdk/intro/`
- ads: `window.CrazyGames.SDK.ad.requestAd("midgame"|"rewarded", callbacks)`
- gameplay lifecycle: `window.CrazyGames.SDK.game.gameplayStart()/gameplayStop()`

The adapter maps:

- OCC interstitial → CrazyGames `midgame`;
- OCC rewarded → CrazyGames `rewarded`;
- OCC gameplay start/stop → CrazyGames gameplay lifecycle.

Reward is confirmed only from `adFinished`; `adError` never grants a reward.

### GamePix

Official JavaScript SDK v3:

- SDK: `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js`
- docs: `https://partners.gamepix.com/sdk/doc/javascript`
- interstitial: `GamePix.interstitialAd()`
- rewarded: `GamePix.rewardAd()`
- initialization contract requires `GamePix.loaded()` before SDK methods.

GamePix ad promises are normalized to OCC ad results. `res.success === true` is required for a rewarded result.

GamePix submission documentation requires its SDK script to be the first script in the final package `<head>`. The provider adapter supports the runtime API now; milestone 13 (Release Pipeline) must inject the GamePix SDK in that required position in the provider-specific ZIP rather than shipping the generic shell unchanged.

### GameMonetize

Official HTML5 SDK:

- SDK: `https://api.gamemonetize.com/sdk.js`
- docs: `https://gamemonetize.com/sdk`
- repository: `https://github.com/GameMonetize/GameMonetize.com-SDK`
- requires a portal-issued GameId;
- ad request: `sdk.showBanner()`;
- lifecycle comes from `SDK_GAME_PAUSE` and `SDK_GAME_START`.

The adapter configures `window.SDK_OPTIONS` before loading the SDK. GameMonetize currently exposes OCC interstitial capability only; rewarded capability is deliberately reported unavailable because the documented HTML5 integration used here does not provide a confirmed rewarded completion contract.

## Ad lifecycle

`AdService` is the only place allowed to pause/resume the game for portal ads.

When `ad_started` arrives:

1. current SceneTree pause state is preserved;
2. master game audio is externally muted without changing the player's volume setting;
3. SceneTree is paused;
4. the ad runs outside Godot.

When `ad_result` arrives:

1. audio is restored according to the player's current setting;
2. the previous SceneTree pause state is restored;
3. the normalized result is returned to the caller.

`PlatformService` and `AdService` run in `PROCESS_MODE_ALWAYS` so provider callbacks remain serviceable while gameplay is paused.

## Placement policy

Interstitials are requested only at natural breaks.

Current integration point:

- successful contract → gameplay stop → optional `contract_complete` interstitial → Headquarters.

Aborted contracts do not trigger an interstitial.

For real providers, `AdService` enforces:

- 90-second initial session grace;
- 90-second interstitial cooldown.

Providers may apply stricter fill/frequency rules themselves. Debug previews bypass the time gate so CI and manual QA can exercise the lifecycle immediately.

Rewarded ads are exposed by `AdService.show_rewarded(placement)` but no player-facing reward placement is added in this milestone. A future UI must clearly disclose the reward and grant it only when the normalized result has `rewarded == true`.

## Testing

CI validates the provider layer without contacting ad networks:

- `.github/scripts/platform-provider-smoke.mjs` runs CrazyGames, GamePix and GameMonetize adapters against deterministic SDK mocks;
- it verifies lifecycle mapping, reward confirmation and the no-debug-fallback rule;
- browser smoke triggers a debug interstitial through the actual Web build and waits for Godot `[Ads] START` / `[Ads] RESULT` logs;
- Godot core contracts require `PlatformService` and `AdService` in `AppRoot`.

Real provider QA still belongs in each portal's official preview/test environment before submission.

## Release packaging boundary

This milestone supplies adapters and lifecycle. It does not create submission ZIPs.

Milestone 13 owns:

- provider-specific SDK placement/injection rules;
- GameMonetize GameId input;
- provider-specific ZIP artifacts;
- manifest/checksums;
- manual release workflow.

GitHub Pages production and all PR previews remain `debug` provider builds.
