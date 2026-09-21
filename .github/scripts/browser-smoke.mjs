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

async function dragTouch(page, viewport) {
  const session = await page.context().newCDPSession(page);
  const start = {
    x: Math.round(viewport.width * 0.66),
    y: Math.round(viewport.height * 0.52),
    radiusX: 1,
    radiusY: 1,
    force: 1,
    id: 0,
  };
  const end = {
    ...start,
    x: Math.round(viewport.width * 0.84),
    y: Math.round(viewport.height * 0.47),
  };

  await session.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [start] });
  await page.waitForTimeout(100);
  await session.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [end] });
  await page.waitForTimeout(320);
  await session.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function openBuild(viewport, label, touch = false) {
  const page = await browser.newPage({ viewport, hasTouch: touch, isMobile: touch });
  watch(page, label);

  const hqReady = waitForConsole(page, '[HQ] READY tab=contracts');
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

  await hqReady;

  // Capture the player-facing headquarters before deployment so visual
  // QA covers the HQ chrome as well as gameplay.
  await page.waitForTimeout(250);
  await page.screenshot({ path: `build/smoke-operations-${label}.png`, fullPage: true });

  const adStarted = waitForConsole(page, '[Ads] START kind=interstitial placement=qa_browser provider=debug', 10000);
  const adResult = waitForConsole(page, '[Ads] RESULT kind=interstitial placement=qa_browser completed=true', 10000);
  const requestId = await page.evaluate(() => window.OCCPlatform.showInterstitial('qa_browser'));
  if (!requestId || !String(requestId).startsWith('debug-interstitial-')) {
    throw new Error('Debug provider did not return a stable interstitial request id');
  }
  await adStarted;
  await adResult;

  // Runtime smoke intentionally uses the debug deep link instead of pixel
  // coordinates. Godot UI is rendered inside one canvas, so coordinate-click
  // tests couple CI to a specific visual layout and break on valid redesigns.
  // The structural Godot suite owns the HQ PrimaryAction contract; browser QA
  // owns Web boot, routed gameplay, input modes and rendered output.
  const sectorReady = waitForConsole(page, '[Sector] READY id=earth_training_01', 30000);
  const contractStarted = waitForConsole(page, '[Contract] START sector=earth_training_01', 30000);
  const deploymentReady = waitForConsole(page, '[Flight] DEPLOYMENT', 30000);
  const flightReady = waitForConsole(page, '[Flight] READY', 30000);
  await page.goto(`${url}?sector=earth_training_01`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await sectorReady;
  await contractStarted;
  const deploymentMessage = (await deploymentReady).text();
  const deploymentMatch = deploymentMessage.match(/position=\(([^)]+)\) depot=\(([^)]+)\)/);
  if (!deploymentMatch || deploymentMatch[1] !== deploymentMatch[2]) {
    throw new Error(`Ship must deploy on cargo depot, received: ${deploymentMessage}`);
  }
  await flightReady;
  await page.waitForTimeout(220);

  if (touch) {
    await dragTouch(page, viewport);
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


async function openQaDeepLinks() {
  const contractSamples = [
    { sector: 'earth_training_02', kind: 'recovery', label: 'recovery' },
    { sector: 'earth_orbit_04', kind: 'valuable_recovery', label: 'valuable' },
    { sector: 'lunar_belt_02', kind: 'full_cleanup', label: 'full-cleanup' },
    { sector: 'blue_nebula_02', kind: 'priority_object', label: 'priority' },
  ];

  for (const sample of contractSamples) {
    const page = await browser.newPage({ viewport: { width: 1100, height: 700 } });
    watch(page, `qa-contract-${sample.label}`);
    const sectorReady = waitForConsole(page, `[Sector] READY id=${sample.sector}`, 60000);
    const contractReady = waitForConsole(page, `[Contract] START sector=${sample.sector} kind=${sample.kind}`, 60000);
    const flightReady = waitForConsole(page, '[Flight] READY', 60000);
    await page.goto(`${url}?sector=${sample.sector}`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await sectorReady;
    await contractReady;
    await flightReady;
    await page.waitForTimeout(250);
    await page.screenshot({ path: `build/smoke-qa-contract-${sample.label}.png`, fullPage: true });
    await page.close();
  }

  const debriefViewports = [
    { label: 'desktop', viewport: { width: 1280, height: 720 } },
    { label: 'portrait', viewport: { width: 390, height: 844 } },
  ];
  for (const sample of debriefViewports) {
    const page = await browser.newPage({
      viewport: sample.viewport,
      hasTouch: sample.label === 'portrait',
      isMobile: sample.label === 'portrait',
    });
    watch(page, `qa-debrief-${sample.label}`);
    const debriefReady = waitForConsole(page, '[Debrief] READY sector=earth_training_02 promoted=true', 60000);
    await page.goto(`${url}?debrief=promotion`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await debriefReady;
    await page.waitForTimeout(1900);
    await page.screenshot({ path: `build/smoke-qa-debrief-${sample.label}.png`, fullPage: true });
    await page.close();
  }

  const endlessPage = await browser.newPage({ viewport: { width: 1100, height: 700 } });
  watch(endlessPage, 'qa-endless-10000');
  const endlessReady = waitForConsole(endlessPage, '[Sector] READY id=endless_010000 seed=4242', 60000);
  await endlessPage.goto(`${url}?endless=10000&seed=4242`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await endlessReady;
  await endlessPage.screenshot({ path: 'build/smoke-qa-endless-10000.png', fullPage: true });
  await endlessPage.close();

  const previewPage = await browser.newPage({ viewport: { width: 1100, height: 700 } });
  watch(previewPage, 'qa-sector-preview');
  const previewReady = waitForConsole(previewPage, '[SectorPreview] READY mode=endless id=endless_010000 seed=4242', 60000);
  await previewPage.goto(`${url}?preview=1&endless=10000&seed=4242`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await previewReady;
  await previewPage.screenshot({ path: 'build/smoke-qa-sector-preview.png', fullPage: true });
  await previewPage.close();
}

try {
  await openBuild(
    { width: 1280, height: 720 },
    'desktop-1280x720',
    false,
  );
  await openBuild(
    { width: 844, height: 390 },
    'mobile-landscape-844x390',
    true,
  );
  await openBuild(
    { width: 390, height: 844 },
    'mobile-portrait-390x844',
    true,
  );
  await openQaDeepLinks();

  if (runtimeErrors.length) {
    throw new Error(runtimeErrors.join('\n'));
  }
  console.log('[QA] Browser smoke passed');
} finally {
  await browser.close();
}
