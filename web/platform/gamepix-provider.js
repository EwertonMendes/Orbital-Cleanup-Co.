(() => {
  const { BaseProvider, loadScriptOnce } = window.OCCProviderUtils;
  const SDK_URL = 'https://integration.gamepix.com/sdk/v3/gamepix.sdk.js';

  class GamePixProvider extends BaseProvider {
    constructor() {
      super('gamepix', ['interstitial', 'rewarded']);
      this.sdk = null;
    }

    async initialize() {
      if (this.initialized) return true;
      try {
        if (!window.GamePix) {
          await loadScriptOnce('occ-gamepix-sdk', SDK_URL);
        }
        this.sdk = window.GamePix ?? null;
        if (!this.sdk) throw new Error('GamePix SDK global is missing');
        if (typeof this.sdk.loaded === 'function') this.sdk.loaded();
        this.initialized = true;
        console.info('[Platform] READY provider=gamepix');
        this._emit('ready', { available: true });
        return true;
      } catch (error) {
        this.capabilities.clear();
        console.warn('[Platform] GamePix SDK unavailable', error);
        this._emit('ready', { available: false, reason: String(error?.message ?? error) });
        return false;
      }
    }

    showInterstitial(placement = 'contract_break') {
      return this.#requestPromiseAd('interstitial', placement, () => this.sdk.interstitialAd());
    }

    showRewarded(placement = 'rewarded') {
      return this.#requestPromiseAd('rewarded', placement, () => this.sdk.rewardAd());
    }

    #requestPromiseAd(kind, placement, request) {
      if (!this.isFeatureAvailable(kind)) return this._unavailable(kind, placement, 'sdk_unavailable');

      const requestId = this._requestId(kind);
      this._emit('ad_started', { requestId, kind, placement });
      Promise.resolve()
        .then(request)
        .then(result => {
          const success = Boolean(result?.success);
          this._emit('ad_result', {
            requestId,
            kind,
            placement,
            completed: success,
            rewarded: kind === 'rewarded' && success,
            reason: success ? 'finished' : 'not_shown',
          });
        })
        .catch(error => {
          this._emit('ad_result', {
            requestId,
            kind,
            placement,
            completed: false,
            rewarded: false,
            reason: String(error?.message ?? error),
          });
        });
      return requestId;
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.gamepix = () => new GamePixProvider();
})();
