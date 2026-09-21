(() => {
  const { BaseProvider, loadScriptOnce } = window.OCCProviderUtils;
  const SDK_URL = 'https://sdk.crazygames.com/crazygames-sdk-v3.js';

  class CrazyGamesProvider extends BaseProvider {
    constructor() {
      super('crazygames', ['interstitial', 'rewarded']);
      this.sdk = null;
    }

    async initialize() {
      if (this.initialized) return true;
      try {
        if (!window.CrazyGames?.SDK) {
          await loadScriptOnce('occ-crazygames-sdk', SDK_URL);
        }
        this.sdk = window.CrazyGames?.SDK ?? null;
        if (!this.sdk) throw new Error('CrazyGames SDK global is missing');
        await this.sdk.init();
        this.initialized = true;
        console.info('[Platform] READY provider=crazygames');
        this._emit('ready', { available: true });
        return true;
      } catch (error) {
        this.capabilities.clear();
        console.warn('[Platform] CrazyGames SDK unavailable', error);
        this._emit('ready', { available: false, reason: String(error?.message ?? error) });
        return false;
      }
    }

    gameplayStarted() {
      if (this.initialized) this.sdk.game.gameplayStart();
    }

    gameplayStopped() {
      if (this.initialized) this.sdk.game.gameplayStop();
    }

    showInterstitial(placement = 'contract_break') {
      return this.#requestAd('midgame', 'interstitial', placement);
    }

    showRewarded(placement = 'rewarded') {
      return this.#requestAd('rewarded', 'rewarded', placement);
    }

    #requestAd(sdkType, kind, placement) {
      if (!this.isFeatureAvailable(kind)) return this._unavailable(kind, placement, 'sdk_unavailable');

      const requestId = this._requestId(kind);
      let settled = false;
      const resolve = (completed, rewarded, reason) => {
        if (settled) return;
        settled = true;
        this._emit('ad_result', { requestId, kind, placement, completed, rewarded, reason });
      };

      try {
        this.sdk.ad.requestAd(sdkType, {
          adStarted: () => this._emit('ad_started', { requestId, kind, placement }),
          adError: error => resolve(false, false, String(error?.message ?? error ?? 'ad_error')),
          adFinished: () => resolve(true, kind === 'rewarded', 'finished'),
        });
      } catch (error) {
        resolve(false, false, String(error?.message ?? error));
      }
      return requestId;
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.crazygames = () => new CrazyGamesProvider();
})();
