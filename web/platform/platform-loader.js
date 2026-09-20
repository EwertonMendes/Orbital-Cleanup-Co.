(() => {
  function createProvider() {
    const requested = String(window.OCC_BUILD?.provider || 'debug').toLowerCase();
    const factory = window.OCCProviders?.[requested];
    if (factory) return factory();

    console.error(`[Platform] requested provider "${requested}" has no registered adapter`);
    return window.OCCProviders.null(requested);
  }

  const provider = createProvider();
  window.OCCPlatform = provider;
  window.OCCPlatformReady = Promise.resolve()
    .then(() => provider.initialize())
    .catch(error => {
      console.error('[Platform] initialization failed', error);
      return false;
    });
})();
