(() => {
  class DebugWebProvider {
    constructor() {
      this.initialized = false;
      this.capabilities = new Set(['interstitial', 'rewarded', 'analytics']);
    }

    async initialize() {
      if (this.initialized) return true;
      this.initialized = true;
      console.info('[Platform] READY provider=debug');
      return true;
    }

    getProviderName() {
      return 'debug';
    }

    isFeatureAvailable(feature) {
      return this.capabilities.has(feature);
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

    async showInterstitial(placement = 'debug') {
      return this.#simulateAd('INTERSTITIAL', placement, false);
    }

    async showRewarded(placement = 'debug') {
      return this.#simulateAd('REWARDED', placement, true);
    }

    pauseExternalAudio() {
      window.dispatchEvent(new CustomEvent('occ:external-audio-pause'));
    }

    resumeExternalAudio() {
      window.dispatchEvent(new CustomEvent('occ:external-audio-resume'));
    }

    async #simulateAd(kind, placement, rewarded) {
      window.dispatchEvent(new CustomEvent('occ:ad:start', { detail: { kind, placement } }));
      const overlay = document.createElement('div');
      overlay.className = 'occ-debug-ad';
      overlay.innerHTML = `<strong>DEBUG ${kind}</strong><span>${placement}</span><small>No real ad network is loaded in previews.</small>`;
      document.body.appendChild(overlay);
      await new Promise(resolve => window.setTimeout(resolve, 700));
      overlay.remove();
      window.dispatchEvent(new CustomEvent('occ:ad:complete', { detail: { kind, placement, rewarded } }));
      return Object.freeze({ completed: true, rewarded, placement, provider: 'debug' });
    }
  }

  window.OCCProviders = window.OCCProviders || {};
  window.OCCProviders.debug = () => new DebugWebProvider();
})();
