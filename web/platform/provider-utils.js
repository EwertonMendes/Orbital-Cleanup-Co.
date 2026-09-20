(() => {
  let requestSequence = 0;

  function nextRequestId(prefix = 'ad') {
    requestSequence += 1;
    return `${prefix}-${Date.now()}-${requestSequence}`;
  }

  function loadScriptOnce(id, src) {
    const existing = document.getElementById(id);
    if (existing) {
      if (existing.dataset.occLoaded === 'true') return Promise.resolve(existing);
      return new Promise((resolve, reject) => {
        existing.addEventListener('load', () => resolve(existing), { once: true });
        existing.addEventListener('error', () => reject(new Error(`Failed to load ${src}`)), { once: true });
      });
    }

    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.id = id;
      script.src = src;
      script.async = true;
      script.addEventListener('load', () => {
        script.dataset.occLoaded = 'true';
        resolve(script);
      }, { once: true });
      script.addEventListener('error', () => reject(new Error(`Failed to load ${src}`)), { once: true });
      document.head.appendChild(script);
    });
  }

  class BaseProvider {
    constructor(name, capabilities = []) {
      this.name = name;
      this.initialized = false;
      this.capabilities = new Set(capabilities);
      this.eventCallback = null;
    }

    setEventCallback(callback) {
      this.eventCallback = typeof callback === 'function' ? callback : null;
    }

    getProviderName() {
      return this.name;
    }

    isFeatureAvailable(feature) {
      return this.initialized && this.capabilities.has(feature);
    }

    gameplayStarted() {}
    gameplayStopped() {}
    trackEvent() {}
    pauseExternalAudio() {}
    resumeExternalAudio() {}

    _requestId(kind) {
      return nextRequestId(`${this.name}-${kind}`);
    }

    _emit(type, detail = {}) {
      const payload = Object.freeze({
        provider: this.name,
        type,
        timestamp: Date.now(),
        ...detail,
      });

      if (typeof window.CustomEvent === 'function' && typeof window.dispatchEvent === 'function') {
        window.dispatchEvent(new CustomEvent(`occ:platform:${type}`, { detail: payload }));
      }
      if (this.eventCallback) {
        this.eventCallback(JSON.stringify(payload));
      }
      return payload;
    }

    _unavailable(kind, placement, reason = 'unsupported') {
      const requestId = this._requestId(kind);
      queueMicrotask(() => this._emit('ad_result', {
        requestId,
        kind,
        placement,
        completed: false,
        rewarded: false,
        reason,
      }));
      return requestId;
    }
  }

  window.OCCProviderUtils = Object.freeze({
    BaseProvider,
    loadScriptOnce,
    nextRequestId,
  });
})();
