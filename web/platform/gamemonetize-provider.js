(() => {
  const { BaseProvider, loadScriptOnce } = window.OCCProviderUtils;
  const SDK_URL = 'https://api.gamemonetize.com/sdk.js';

  class GameMonetizeProvider extends BaseProvider {
    constructor() {
      super('gamemonetize', ['interstitial']);
      this.sdk = null;
      this.pending = null;
      this.timeout = null;
    }

    async initialize() {
      if (this.initialized) return true;
      const gameId = String(window.OCC_BUILD?.providerSettings?.gameMonetizeGameId ?? '').trim();
      if (!gameId) {
        this.capabilities.clear();
        console.warn('[Platform] GameMonetize gameId is not configured');
        this._emit('ready', { available: false, reason: 'missing_game_id' });
        return false;
      }

      try {
        const previousOnEvent = window.SDK_OPTIONS?.onEvent;
        window.SDK_OPTIONS = {
          ...(window.SDK_OPTIONS || {}),
          gameId,
          onEvent: event => {
            if (typeof previousOnEvent === 'function') previousOnEvent(event);
            this.#handleSdkEvent(event);
          },
        };

        if (!window.sdk) {
          await loadScriptOnce('gamemonetize-sdk', SDK_URL);
        }
        this.sdk = window.sdk ?? null;
        if (!this.sdk || typeof this.sdk.showBanner !== 'function') {
          throw new Error('GameMonetize sdk.showBanner is missing');
        }

        this.initialized = true;
        console.info('[Platform] READY provider=gamemonetize');
        this._emit('ready', { available: true });
        return true;
      } catch (error) {
        this.capabilities.clear();
        console.warn('[Platform] GameMonetize SDK unavailable', error);
        this._emit('ready', { available: false, reason: String(error?.message ?? error) });
        return false;
      }
    }

    showInterstitial(placement = 'contract_break') {
      if (!this.isFeatureAvailable('interstitial')) {
        return this._unavailable('interstitial', placement, 'sdk_unavailable');
      }
      if (this.pending) {
        return this._unavailable('interstitial', placement, 'ad_already_pending');
      }

      const requestId = this._requestId('interstitial');
      this.pending = { requestId, kind: 'interstitial', placement, started: false };
      this.timeout = window.setTimeout(() => this.#resolvePending(false, 'timeout'), 30000);

      try {
        this.sdk.showBanner();
      } catch (error) {
        this.#resolvePending(false, String(error?.message ?? error));
      }
      return requestId;
    }

    showRewarded(placement = 'rewarded') {
      return this._unavailable('rewarded', placement, 'unsupported');
    }

    #handleSdkEvent(event) {
      const name = String(event?.name ?? '');
      if (name === 'SDK_GAME_PAUSE' && this.pending && !this.pending.started) {
        this.pending.started = true;
        this._emit('ad_started', { ...this.pending });
      } else if (name === 'SDK_GAME_START' && this.pending) {
        this.#resolvePending(true, 'finished');
      }
    }

    #resolvePending(completed, reason) {
      if (!this.pending) return;
      if (this.timeout) window.clearTimeout(this.timeout);
      const result = this.pending;
      this.pending = null;
      this.timeout = null;
      this._emit('ad_result', {
        ...result,
        completed,
        rewarded: false,
        reason,
      });
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.gamemonetize = () => new GameMonetizeProvider();
})();
