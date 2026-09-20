# Platform Integration

## Boundary

Portal SDKs are adapters, not gameplay dependencies.

Godot will eventually talk to project-owned services such as `PlatformService`, `AdService` and `AnalyticsService`. JavaScript owns provider-specific SDK details.

## Web layout

```text
web/
  shell/index.html
  platform/
    platform-config.js
    platform-loader.js
    debug-provider.js
    crazygames-provider.js       # later
    gamepix-provider.js          # later
    gamemonetize-provider.js     # later
```

The same source tree will produce provider-specific Web packages. Build configuration selects the provider; the game is not forked.

## DebugWebProvider

PR previews and GitHub Pages use `DebugWebProvider` exclusively.

It:

- does not load a network ad SDK;
- reports provider name `debug`;
- simulates interstitial/rewarded flows locally;
- exposes capability checks;
- emits lifecycle events useful for future pause/resume integration.

This makes ad-flow behavior testable before any portal credentials or approval.

## Planned provider surface

Conceptually:

```text
initialize()
get_provider_name()
is_feature_available(feature)
gameplay_started()
gameplay_stopped()
show_interstitial(placement)
show_rewarded(placement)
track_event(event_name, payload)
pause_external_audio()
resume_external_audio()
```

Ad results must be asynchronous and explicit. A rewarded benefit is granted only after confirmed completion.

## Ad placement policy

Interstitials belong only at natural breaks such as between contracts/return to headquarters. Never interrupt active exploration.

Rewarded examples may include payout bonus, contract reroll or small temporary boost. The game must remain functional when a provider does not support ads.
