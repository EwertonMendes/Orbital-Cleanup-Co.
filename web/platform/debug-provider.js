(() => {
  const { BaseProvider } = window.OCCProviderUtils;

  class DebugWebProvider extends BaseProvider {
    constructor() {
      super('debug', ['interstitial', 'rewarded', 'analytics']);
    }

    async initialize() {
      if (this.initialized) return true;
      this.initialized = true;
      console.info('[Platform] READY provider=debug');
      this._emit('ready', { available: true });
      return true;
    }

    gameplayStarted() {
      console.info('[Platform] gameplay_started');
    }

    gameplayStopped() {
      console.info('[Platform] gameplay_stopped');
    }

    trackEvent(eventName, payload = {}) {
      console.info('[Platform] event', eventName, payload);
    }

    showInterstitial(placement = 'debug') {
      return this.#simulateAd('interstitial', placement, false);
    }

    showRewarded(placement = 'debug') {
      return this.#simulateAd('rewarded', placement, true);
    }

    #simulateAd(kind, placement, rewarded) {
      const requestId = this._requestId(kind);
      this._emit('ad_started', { requestId, kind, placement });

      const overlay = document.createElement('div');
      overlay.className = 'occ-debug-ad';
      overlay.innerHTML = `<strong>DEBUG ${kind.toUpperCase()}</strong><span>${placement}</span><small>No real ad network is loaded in previews.</small>`;
      document.body.appendChild(overlay);

      window.setTimeout(() => {
        overlay.remove();
        this._emit('ad_result', {
          requestId,
          kind,
          placement,
          completed: true,
          rewarded,
          reason: 'debug_complete',
        });
      }, 700);

      return requestId;
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.debug = () => new DebugWebProvider();
})();
