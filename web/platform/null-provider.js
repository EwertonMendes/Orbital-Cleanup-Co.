(() => {
  const { BaseProvider } = window.OCCProviderUtils;

  class NullProvider extends BaseProvider {
    constructor(requested = 'unknown') {
      super('null', []);
      this.requested = requested;
    }

    async initialize() {
      this.initialized = true;
      console.warn(`[Platform] provider "${this.requested}" is unavailable; continuing without portal features`);
      this._emit('ready', { available: false, requested: this.requested });
      return false;
    }

    showInterstitial(placement = 'interstitial') {
      return this._unavailable('interstitial', placement, 'provider_unavailable');
    }

    showRewarded(placement = 'rewarded') {
      return this._unavailable('rewarded', placement, 'provider_unavailable');
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.null = requested => new NullProvider(requested);
})();
