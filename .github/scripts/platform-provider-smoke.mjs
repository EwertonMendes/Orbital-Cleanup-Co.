import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const ROOT = new URL('../../', import.meta.url);
const scripts = [
  'web/platform/provider-utils.js',
  'web/platform/null-provider.js',
  'web/platform/debug-provider.js',
  'web/platform/crazygames-provider.js',
  'web/platform/gamepix-provider.js',
  'web/platform/gamemonetize-provider.js',
];

function makeSandbox() {
  const elements = new Map();
  const bodyChildren = [];
  const sandbox = {
    console,
    setTimeout,
    clearTimeout,
    queueMicrotask,
    Date,
    Promise,
    JSON,
    Object,
    Set,
    String,
    Boolean,
    Error,
    CustomEvent: class CustomEvent {
      constructor(type, init = {}) {
        this.type = type;
        this.detail = init.detail;
      }
    },
    dispatchEvent() {},
    addEventListener() {},
    document: {
      getElementById(id) {
        return elements.get(id) ?? null;
      },
      createElement(tag) {
        const listeners = {};
        return {
          tagName: tag.toUpperCase(),
          dataset: {},
          className: '',
          innerHTML: '',
          id: '',
          src: '',
          async: false,
          addEventListener(type, callback) {
            listeners[type] = callback;
          },
          remove() {
            const index = bodyChildren.indexOf(this);
            if (index >= 0) bodyChildren.splice(index, 1);
          },
          _listeners: listeners,
        };
      },
      head: {
        appendChild(element) {
          if (element.id) elements.set(element.id, element);
        },
      },
      body: {
        appendChild(element) {
          bodyChildren.push(element);
        },
      },
    },
  };
  sandbox.window = sandbox;
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);

  for (const relative of scripts) {
    const source = fs.readFileSync(new URL(relative, ROOT), 'utf8');
    vm.runInContext(source, sandbox, { filename: relative });
  }
  return sandbox;
}

function capture(provider) {
  const events = [];
  provider.setEventCallback(raw => events.push(JSON.parse(raw)));
  return events;
}

async function nextTurn() {
  await new Promise(resolve => setTimeout(resolve, 0));
}

async function testCrazyGames() {
  const s = makeSandbox();
  const calls = [];
  s.CrazyGames = {
    SDK: {
      async init() { calls.push('init'); },
      game: {
        gameplayStart() { calls.push('gameplayStart'); },
        gameplayStop() { calls.push('gameplayStop'); },
      },
      ad: {
        requestAd(type, callbacks) {
          calls.push(`ad:${type}`);
          callbacks.adStarted();
          callbacks.adFinished();
        },
      },
    },
  };

  const provider = s.OCCProviders.crazygames();
  const events = capture(provider);
  assert.equal(await provider.initialize(), true);
  provider.gameplayStarted();
  provider.gameplayStopped();
  const requestId = provider.showRewarded('qa_reward');
  await nextTurn();

  assert.ok(requestId.startsWith('crazygames-rewarded-'));
  assert.deepEqual(calls, ['init', 'gameplayStart', 'gameplayStop', 'ad:rewarded']);
  assert.equal(events.find(e => e.type === 'ad_started')?.requestId, requestId);
  const result = events.find(e => e.type === 'ad_result');
  assert.equal(result?.completed, true);
  assert.equal(result?.rewarded, true);
}

async function testGamePix() {
  const s = makeSandbox();
  let loaded = 0;
  s.GamePix = {
    loaded() { loaded += 1; },
    interstitialAd() { return Promise.resolve({ success: true }); },
    rewardAd() { return Promise.resolve({ success: true }); },
  };

  const provider = s.OCCProviders.gamepix();
  const events = capture(provider);
  assert.equal(await provider.initialize(), true);
  assert.equal(loaded, 1);

  const requestId = provider.showInterstitial('qa_break');
  await nextTurn();
  assert.equal(events.find(e => e.type === 'ad_started')?.requestId, requestId);
  const result = events.find(e => e.type === 'ad_result');
  assert.equal(result?.completed, true);
  assert.equal(result?.rewarded, false);
}

async function testGameMonetize() {
  const s = makeSandbox();
  s.OCC_BUILD = { providerSettings: { gameMonetizeGameId: 'qa-game-id' } };
  s.sdk = {
    showBanner() {
      queueMicrotask(() => {
        s.SDK_OPTIONS.onEvent({ name: 'SDK_GAME_PAUSE' });
        s.SDK_OPTIONS.onEvent({ name: 'SDK_GAME_START' });
      });
    },
  };

  const provider = s.OCCProviders.gamemonetize();
  const events = capture(provider);
  assert.equal(await provider.initialize(), true);
  assert.equal(provider.isFeatureAvailable('interstitial'), true);
  assert.equal(provider.isFeatureAvailable('rewarded'), false);

  const requestId = provider.showInterstitial('qa_break');
  await nextTurn();
  assert.equal(events.find(e => e.type === 'ad_started')?.requestId, requestId);
  const result = events.find(e => e.type === 'ad_result');
  assert.equal(result?.completed, true);
  assert.equal(result?.rewarded, false);
}

async function testUnknownProviderDoesNotBecomeDebug() {
  const s = makeSandbox();
  s.OCC_BUILD = { provider: 'not-a-provider' };
  const loader = fs.readFileSync(new URL('web/platform/platform-loader.js', ROOT), 'utf8');
  vm.runInContext(loader, s, { filename: 'web/platform/platform-loader.js' });
  await s.OCCPlatformReady;
  assert.equal(s.OCCPlatform.getProviderName(), 'null');
  assert.equal(s.OCCPlatform.isFeatureAvailable('interstitial'), false);
}

await testCrazyGames();
await testGamePix();
await testGameMonetize();
await testUnknownProviderDoesNotBecomeDebug();
console.log('[QA] Platform provider contracts passed');
