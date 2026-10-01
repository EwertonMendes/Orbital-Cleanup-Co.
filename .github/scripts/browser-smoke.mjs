import { chromium } from 'playwright';

const url = process.env.OCC_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
  args: [
    '--disable-background-timer-throttling',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
  ],
});

const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const runtimeErrors = [];

page.on('pageerror', error => runtimeErrors.push(`pageerror: ${error.message}`));
page.on('console', message => {
  const text = message.text();
  if (message.type() === 'error' || text.includes('[OCC] WEB_BOOT_FAILED')) {
    runtimeErrors.push(`console: ${text}`);
  }
});
page.on('response', response => {
  if (response.status() >= 400) {
    runtimeErrors.push(`http ${response.status()}: ${response.url()}`);
  }
});

function waitForConsole(marker, timeout = 20000) {
  return page.waitForEvent('console', {
    predicate: message => message.text().includes(marker),
    timeout,
  });
}

try {
  const ready = waitForConsole('[OCC] READY');
  const sectorReady = waitForConsole('[Sector] READY id=earth_training_01');
  const flightReady = waitForConsole('[Flight] READY mode=free_roam');
  const speedometerReady = waitForConsole('[HUD] SPEEDOMETER_READY');

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForSelector('canvas', { state: 'visible', timeout: 20000 });
  await Promise.all([ready, sectorReady, flightReady, speedometerReady]);

  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 10000 });

  const runtime = await page.evaluate(() => ({
    provider: window.OCCPlatform?.getProviderName?.(),
    build: window.OCC_BUILD,
  }));
  if (runtime.provider !== 'debug' || runtime.build?.provider !== 'debug') {
    throw new Error('Web runtime did not boot with the debug preview provider');
  }

  // One live browser session is enough for the release gate. Structural and
  // content coverage belongs to the fast headless validators.
  const operationsOpen = waitForConsole('[Flight] OPERATIONS_OPEN', 10000);
  const hqReady = waitForConsole('[HQ] READY tab=contracts mode=overlay', 10000);
  await page.keyboard.press('Escape');
  await Promise.all([operationsOpen, hqReady]);

  const operationsClosed = waitForConsole('[Flight] OPERATIONS_CLOSED', 10000);
  await page.keyboard.press('Escape');
  await operationsClosed;

  if (runtimeErrors.length) {
    throw new Error(runtimeErrors.join('\n'));
  }

  console.log('[QA] Browser smoke passed');
} finally {
  await browser.close();
}
