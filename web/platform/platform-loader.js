(() => {
  function createProvider() {
    const requested = window.OCC_BUILD?.provider || 'debug';
    const factory = window.OCCProviders?.[requested];
    if (factory) return factory();

    console.warn(`[Platform] provider "${requested}" is unavailable; falling back to debug`);
    return window.OCCProviders.debug();
  }

  const provider = createProvider();
  window.OCCPlatform = provider;
  window.OCCPlatformReady = Promise.resolve(provider.initialize());
})();
