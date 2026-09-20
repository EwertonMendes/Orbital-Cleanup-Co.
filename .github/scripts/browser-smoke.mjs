import { chromium } from 'playwright';

const url = process.env.OCC_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROME_BIN ?? '/usr/bin/google-chrome',
});

const runtimeErrors = [];

function watch(page, label) {
  page.on('pageerror', error => runtimeErrors.push(`${label} pageerror: ${error.message}`));
  page.on('console', message => {
    const text = message.text();
    if (message.type() === 'error' || text.includes('[OCC] WEB_BOOT_FAILED')) {
      const location = message.location();
      const source = location?.url ? ` [${location.url}:${location.lineNumber ?? 0}]` : '';
      runtimeErrors.push(`${label} console: ${text}${source}`);
    }
  });
  page.on('response', response => {
    if (response.status() >= 400) {
      runtimeErrors.push(`${label} http ${response.status()}: ${response.url()}`);
    }
  });
}

function waitForConsole(page, marker, timeout = 60000) {
  return page.waitForEvent('console', {
    predicate: message => message.text().includes(marker),
    timeout,
  });
}

async function activateAt(page, point, touch) {
  if (touch) {
    await page.touchscreen.tap(point.x, point.y);
  } else {
    await page.mouse.click(point.x, point.y);
  }
}

async function openBuild(viewport, label, deployPoint, touch = false) {
  const page = await browser.newPage({ viewport, hasTouch: touch, isMobile: touch });
  watch(page, label);

  const ready = waitForConsole(page, '[OCC] READY');
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForSelector('canvas', { state: 'visible', timeout: 60000 });
  await ready;
  await page.waitForFunction(() => {
    const canvas = document.querySelector('canvas');
    return canvas && canvas.width > 100 && canvas.height > 100;
  }, null, { timeout: 60000 });

  const runtime = await page.evaluate(() => ({
    provider: window.OCCPlatform?.getProviderName?.(),
    build: window.OCC_BUILD,
  }));

  if (runtime.provider !== 'debug') {
    throw new Error(`Expected debug provider in CI/Pages preview, received ${runtime.provider}`);
  }
  if (!runtime.build || runtime.build.provider !== 'debug') {
    throw new Error('Missing debug OCC_BUILD metadata');
  }

  const flightReady = waitForConsole(page, '[Flight] READY', 15000);
  await activateAt(page, deployPoint, touch);
  await flightReady;
  await page.waitForTimeout(300);

  if (touch) {
    await page.touchscreen.tap(Math.round(viewport.width * 0.78), Math.round(viewport.height * 0.52));
  } else {
    await page.mouse.move(Math.round(viewport.width * 0.80), Math.round(viewport.height * 0.50));
    await page.keyboard.down('d');
    await page.waitForTimeout(260);
    await page.keyboard.up('d');
  }

  await page.waitForTimeout(420);
  await page.screenshot({ path: `build/smoke-${label}.png`, fullPage: true });
  await page.close();
}

try {
  await openBuild(
    { width: 1280, height: 720 },
    'desktop-1280x720',
    { x: 330, y: 648 },
    false,
  );
  await openBuild(
    { width: 844, height: 390 },
    'mobile-landscape-844x390',
    { x: 218, y: 350 },
    true,
  );
  await openBuild(
    { width: 390, height: 844 },
    'mobile-portrait-390x844',
    { x: 194, y: 414 },
    true,
  );

  if (runtimeErrors.length) {
    throw new Error(runtimeErrors.join('\n'));
  }
  console.log('[QA] Browser smoke passed');
} finally {
  await browser.close();
}
