#!/usr/bin/env node
// Screen matrix for the Flutter web build (Q001; AIONIA §14.10/§14.11): open
// every main screen for real in Chromium at phone, tablet and desktop sizes,
// in English and Turkish, with the Matrix, Axolotl and Trans palettes and with
// 2× text, and report PASS / FAIL / NOT TESTED per cell. It is a report: the
// exit code is 0 even when cells fail (non-zero only when the tool itself
// cannot run).
//
// Usage: node tools/flutter_screen_matrix.mjs [--build <dir>] [--debug-build <dir>] [--out <dir>]
//   --build        release web build (default human_health_os/build/web)
//   --debug-build  `flutter build web --debug` of the same revision. Flutter
//                  reports layout overflow ("A RenderFlex overflowed") only in
//                  debug builds, so the overflow check runs there; without it
//                  that check is NOT TESTED in every cell.
//   --out          default reports/runtime/screen-matrix/<rev12>
// Shares the server, semantics enable and navigation approach of
// tools/flutter_web_smoke.mjs.
import { createServer } from 'node:http';
import { readFile, stat, mkdir, writeFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { chromium } from '@playwright/test';

const arg = (name, fallback) => {
  const i = process.argv.indexOf(name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
};
const gitRev = (() => { try { return execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(); } catch { return 'unknown'; } })();
const gitDirty = (() => { try { return execFileSync('git', ['status', '--porcelain', '--', '.', ':!reports', ':!evidence'], { encoding: 'utf8' }).trim() !== ''; } catch { return null; } })();
const releaseRoot = resolve(arg('--build', 'human_health_os/build/web'));
const debugRoot = arg('--debug-build', null) ? resolve(arg('--debug-build')) : null;
const out = resolve(arg('--out', `reports/runtime/screen-matrix/${gitRev.slice(0, 12)}`));
const cacheDir = arg('--cache', null) ? resolve(arg('--cache')) : null;
const sha256 = async (f) => createHash('sha256').update(await readFile(f)).digest('hex');
await mkdir(out, { recursive: true });
if (cacheDir) await mkdir(cacheDir, { recursive: true });

// ---- static server (same as flutter_web_smoke.mjs) -------------------------
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css', '.symbols': 'application/octet-stream', '.frag': 'application/octet-stream' };
const serve = async (root) => {
  const server = createServer(async (req, res) => {
    try {
      let p = join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
      if ((await stat(p).catch(() => null))?.isDirectory()) p = join(p, 'index.html');
      const body = await readFile(p);
      res.writeHead(200, { 'content-type': TYPES[extname(p)] ?? 'application/octet-stream' });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return { server, base: `http://127.0.0.1:${server.address().port}/` };
};

// ---- the matrix -------------------------------------------------------------
// Touch sizes present a phone/tablet browser (Android Chrome user agent, touch,
// mobile viewport), so Flutter picks the platform such a device would get.
const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';
const ANDROID_TABLET_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
const VIEWPORTS = {
  'small-phone': { width: 320, height: 640, touch: true, ua: ANDROID_UA },
  phone: { width: 390, height: 844, touch: true, ua: ANDROID_UA },
  'tablet-portrait': { width: 820, height: 1180, touch: true, ua: ANDROID_TABLET_UA },
  'tablet-landscape': { width: 1180, height: 820, touch: true, ua: ANDROID_TABLET_UA },
  desktop: { width: 1440, height: 900, touch: false, ua: null },
};
const LOCALES = ['en-US', 'tr-TR'];
// [id, navigation item, heading, kind]; kind: tab (primary), area (More), settings.
const SCREENS = {
  'en-US': [
    ['Today', 'Today', 'Today', 'tab'],
    ['Timeline', 'Timeline', 'Timeline', 'tab'],
    ['Labs', 'Labs', 'Labs', 'tab'],
    ['Medications', 'Medications', 'Medicines and supplements', 'tab'],
    ['Nutrition', 'Nutrition', 'Nutrition', 'area'],
    ['Activity', 'Activity', 'Activity', 'area'],
    ['Conditions', 'Conditions', 'Conditions and symptoms', 'area'],
    ['Preventive', 'Preventive', 'Vaccinations, screenings, check-ups', 'area'],
    ['Documents', 'Documents', 'Documents', 'area'],
    ['Learn', 'Learn', 'Learn', 'area'],
    ['Settings', 'Settings', 'Settings', 'settings'],
  ],
  'tr-TR': [
    ['Today', 'Bugün', 'Bugün', 'tab'],
    ['Timeline', 'Zaman çizelgesi', 'Zaman çizelgesi', 'tab'],
    ['Labs', 'Tahliller', 'Tahliller', 'tab'],
    ['Medications', 'İlaçlar', 'İlaçlar ve takviyeler', 'tab'],
    ['Nutrition', 'Beslenme', 'Beslenme', 'area'],
    ['Activity', 'Aktivite', 'Aktivite', 'area'],
    ['Conditions', 'Durumlar', 'Durumlar ve belirtiler', 'area'],
    ['Preventive', 'Koruyucu', 'Aşılar, taramalar, kontroller', 'area'],
    ['Documents', 'Belgeler', 'Belgeler', 'area'],
    ['Learn', 'Öğren', 'Öğren', 'area'],
    ['Settings', 'Ayarlar', 'Ayarlar', 'settings'],
  ],
};
// Settings has one heading level per section (U035): its first is the
// light-or-dark section's title (U038: the most used first).
const SETTINGS_FIRST_HEADING = { 'en-US': 'Light or dark', 'tr-TR': 'Açık veya koyu' };
const MORE = { 'en-US': 'More', 'tr-TR': 'Diğer' };
// The back button is named once (R016: Flutter's Android icon label, which
// repeated the tooltip as "Back Back", is removed by the app theme).
const BACK = { 'en-US': /^Back$/, 'tr-TR': /^Geri$/ };
const ALL = SCREENS['en-US'].map(([id]) => id);
// One group = one page load; its cells are visited in order.
const GROUPS = [];
for (const vp of Object.keys(VIEWPORTS)) for (const locale of LOCALES) GROUPS.push({ variant: 'base', vp, locale, screens: ALL });
for (const palette of ['Matrix', 'Axolotl', 'Trans']) for (const vp of ['phone', 'desktop']) GROUPS.push({ variant: `palette-${palette.toLowerCase()}`, palette, vp, locale: 'en-US', screens: ['Settings', 'Today'] });
// 2× text through the browser's font size (the root font size Flutter web
// reads as its text scale), as a person with a large browser font gets.
for (const locale of LOCALES) GROUPS.push({ variant: 'text-2x', fontSize: '32px', vp: 'small-phone', locale, screens: ALL });
// Q002/Q003: sheets, sub-pages and deep sections that a screen's first view
// does not show: the Labs add sheet, "More from the report", "Same test over
// time" (F004-S4), Settings palettes, app lock and About Human OS (U032), and
// the restore-from-file entry of Today's "Your data" card; Q004 (after
// U036–U038): the lab sheet with a field's "What to type here" open, the
// dose sheet a Medications card's "I took it" opens, and a Timeline record's
// sheet with its Details open. At 320x640 (1× and
// 2× text) and on the desktop, in both languages.
const EXTRA_IDS = [
  'Labs: add sheet',
  'Labs: field details',
  'Labs: more from the report',
  'Labs: same test over time',
  'Medications: I took it',
  'Timeline: record details',
  'Settings: palettes',
  'Settings: app lock',
  'Settings: about',
  'Today: restore from file',
];
for (const locale of LOCALES) {
  GROUPS.push({ variant: 'sheets', vp: 'small-phone', locale, screens: EXTRA_IDS });
  GROUPS.push({ variant: 'sheets', vp: 'desktop', locale, screens: EXTRA_IDS });
  GROUPS.push({ variant: 'sheets-text-2x', fontSize: '32px', vp: 'small-phone', locale, screens: EXTRA_IDS });
}
// The words the extra cells look for (lib/src/l10n/strings.dart).
const X_TEXT = {
  'en-US': {
    labAdd: 'Add a result', labAddTitle: 'Add a result from a report', labMore: 'More from the report',
    labInterval: 'Reference interval as printed (optional)',
    labAnalyte: /^Test name as printed/, labValue: /^Value/, labUnit: /^Unit as printed/, labDate: /^Sample date/, save: 'Save',
    labGroupsTitle: 'Same test over time', labGroupBtn: 'HbA1c · %: 2 results', labGroupTitle: 'HbA1c over time', labGroupEvery: 'Every result, newest first',
    labGroupChartSpoken: /^Chart of 2 number results in percent/,
    palette: 'Palette', lock: 'Lock after inactivity',
    lockReason: 'Not available in this build: it saves without encryption (a development build), so there is no key to drop. The lock works in builds with an encrypted vault.',
    lockControls: /^(Off|\d+ min|Lock when the app is hidden)/,
    about: 'About Human OS', aboutBuild: 'This build', aboutCaps: 'Capabilities on this device',
    restore: 'Restore from a backup file', noFile: 'No file chosen. Nothing was changed.',
    fieldDetailsAnalyte: /^What to type here: Test name as printed/,
    labAnalyteDetails: 'Similar names are kept apart: Human OS never guesses that two different names are the same test.',
    medsAdd: 'Add a medicine or supplement', medsName: /^Name \(as on the pack\)/, medsTookIt: 'I took it', medsDose: 'Record a dose',
    versions: 'Versions', detailsToggle: /^Details: HbA1c$/, enteredOn: 'entered',
  },
  'tr-TR': {
    labAdd: 'Sonuç ekle', labAddTitle: 'Rapordan sonuç ekle', labMore: 'Rapordaki diğer bilgiler',
    labInterval: 'Raporda yazan referans aralığı (isteğe bağlı)',
    labAnalyte: /^Raporda yazan test adı/, labValue: /^Değer/, labUnit: /^Raporda yazan birim/, labDate: /^Numune tarihi/, save: 'Kaydet',
    labGroupsTitle: 'Aynı test, zaman içinde', labGroupBtn: 'HbA1c · %: 2 sonuç', labGroupTitle: 'HbA1c, zaman içinde', labGroupEvery: 'Tüm sonuçlar, yeniden eskiye',
    labGroupChartSpoken: /^yüzde cinsinden 2 sayısal sonucun grafiği/,
    palette: 'Renk paleti', lock: 'Kullanılmayınca kilitle',
    lockReason: 'Bu sürümde yok: kayıtlar şifresiz tutuluyor (geliştirme sürümü), bu yüzden bellekten silinecek bir anahtar yok. Kilit, şifreli kasası olan sürümlerde çalışır.',
    lockControls: /^(Kapalı|\d+ dk|Uygulama gizlenince kilitle)/,
    about: 'Human OS hakkında', aboutBuild: 'Bu sürüm', aboutCaps: 'Bu cihazda neler çalışıyor',
    restore: 'Bir yedek dosyasından geri yükle', noFile: 'Dosya seçilmedi. Hiçbir şey değişmedi.',
    fieldDetailsAnalyte: /^Ne yazılır\?: Raporda yazan test adı/,
    labAnalyteDetails: 'Benzer adlar ayrı tutulur: Human OS farklı iki adın aynı test olduğunu tahmin etmez.',
    medsAdd: 'İlaç ya da takviye ekle', medsName: /^Adı \(kutudaki gibi\)/, medsTookIt: 'Aldım', medsDose: 'Doz kaydet',
    versions: 'Sürümler', detailsToggle: /^Ayrıntılar: HbA1c$/, enteredOn: 'kayıt zamanı:',
  },
};

// MATRIX_ONLY=<regex> limits the run to groups whose "variant vp locale"
// matches (for debugging the tool); MATRIX_VERBOSE=1 logs each step.
if (process.env.MATRIX_ONLY) {
  const re = new RegExp(process.env.MATRIX_ONLY);
  GROUPS.splice(0, GROUPS.length, ...GROUPS.filter((g) => re.test(`${g.variant} ${g.vp} ${g.locale}`)));
}
const log = (...a) => { if (process.env.MATRIX_VERBOSE) console.log(new Date().toISOString().slice(11, 19), ...a); };

const MIN_TARGET = 44;
const TARGET_ROLES = ['button', 'link', 'tab', 'checkbox', 'switch', 'radio', 'menuitem', 'slider', 'option'];
const NAMED_ROLES = ['button', 'link', 'tab'];
// Flutter's MaterialLocalizations.scrimLabel (en, tr): the modal barrier.
const SCRIM = /^(Scrim|opaklık katmanı)$/i;

// ---- one pass over every group -----------------------------------------------
const browser = await chromium.launch(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {});
const browserVersion = browser.version();

const cellId = (g, screen) => `${g.variant}|${g.vp}|${g.locale}|${screen}`;

async function runPass(root, mode) {
  const { server, base } = await serve(root);
  const buildHash = await sha256(join(root, 'main.dart.js')).catch(() => 'missing');
  const cells = {};
  for (const g of GROUPS) {
    const cacheFile = cacheDir ? join(cacheDir, `${mode}_${g.variant}_${g.vp}_${g.locale}_${buildHash.slice(0, 12)}.json`) : null;
    if (cacheFile) {
      const raw = await readFile(cacheFile, 'utf8').catch(() => null);
      if (raw) {
        try {
          const cached = JSON.parse(raw);
          const shotsOk = mode !== 'release' || (await Promise.all(
            Object.values(cached.cells ?? {}).map((c) => !c.screenshot || stat(join(out, c.screenshot)).then(() => true, () => false)),
          )).every(Boolean);
          if (cached.gitRev === gitRev && cached.buildHash === buildHash && cached.browser === browserVersion && shotsOk) {
            Object.assign(cells, cached.cells);
            process.stdout.write(`${mode} ${g.variant} ${g.vp} ${g.locale} cached\n`);
            continue;
          }
        } catch {}
      }
    }
    const groupKeys = [];
    const vp = VIEWPORTS[g.vp];
    const ctx = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      locale: g.locale,
      deviceScaleFactor: 1,
      ...(vp.touch ? { hasTouch: true, isMobile: true, userAgent: vp.ua } : {}),
    });
    const page = await ctx.newPage();
    if (g.fontSize) {
      await page.addInitScript((f) => {
        document.addEventListener('DOMContentLoaded', () => { document.documentElement.style.fontSize = f; });
      }, g.fontSize);
    }
    // Everything the page reports goes to the cell open at the time; what
    // happens while loading goes to the group's first cell.
    let sink = { pageErrors: [], consoleErrors: [], failedRequests: [], overflow: [], flutterErrors: [] };
    page.on('pageerror', (e) => sink.pageErrors.push(e.message.slice(0, 300)));
    page.on('console', (m) => {
      const t = m.text();
      if (m.type() === 'error') sink.consoleErrors.push(t.slice(0, 300));
      if (/overflowed by [\d.]+ pixels/.test(t)) sink.overflow.push((t.match(/A [A-Za-z]+ overflowed by [\d.]+ pixels on the \w+/) ?? [t.slice(0, 160)])[0]);
      else if (/EXCEPTION CAUGHT BY|Another exception was thrown/.test(t)) sink.flutterErrors.push(t.replace(/═+/g, '').trim().slice(0, 200));
    });
    page.on('requestfailed', (r) => sink.failedRequests.push(`${r.url()} (${r.failure()?.errorText ?? 'failed'})`));
    page.on('response', (r) => { if (r.status() >= 400) sink.failedRequests.push(`${r.url()} (HTTP ${r.status()})`); });

    log('load', g.variant, g.vp, g.locale);
    await page.goto(base, { waitUntil: 'load' });
    await page.waitForSelector('flutter-view', { state: 'attached', timeout: 120_000 });
    for (let i = 0; i < 60 && (await page.locator('flt-semantics').count()) === 0; i++) {
      // A mobile browser enables semantics only for a click at the centre of
      // the full-page placeholder (Flutter's MobileSemanticsEnabler).
      const ph = page.locator('flt-semantics-placeholder');
      if (vp.touch) await ph.click({ force: true, timeout: 2_000 }).catch(() => {});
      else await ph.dispatchEvent('click').catch(() => {});
      await page.waitForTimeout(500);
    }
    const H = (name) => page.getByRole('heading', { name, exact: true }).first();
    const names = Object.fromEntries(SCREENS[g.locale].map(([id, nav, heading, kind]) => [id, { nav, heading, kind }]));
    await H(names.Today.heading).waitFor({ timeout: 60_000 }).catch(() => {});
    const skip = page.getByRole('button', { name: /^(Skip|Atla)$/ }).first();
    if ((await skip.count()) > 0) await skip.click().catch(() => {});

    const navItem = (name) => page.getByRole('tab', { name, exact: true }).or(page.getByRole('button', { name: new RegExp(`^${esc(name)}( |$)`) })).first();
    // After a palette change (and on desktop Settings since U038) Chromium
    // reports an empty full-window semantics node (pointer-events: auto)
    // above the page, so Playwright's actionability check refuses the
    // click. Retrying makes Playwright scroll the element into view through
    // the DOM, which moves Flutter's scrollables (a page jump and a shifted
    // palette row were seen, Q004) so a later click lands on another
    // control. Flutter hit-tests by position, so a control already on
    // screen is clicked at its centre, as a person's tap or click is.
    const tap = async (locator, timeout = 10_000) => {
      const b = await locator.boundingBox({ timeout: 3_000 }).catch(() => null);
      if (b && b.y >= 0 && b.y + b.height <= vp.height && b.x >= 0 && b.x + b.width <= vp.width) {
        await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
        return;
      }
      try {
        await locator.click({ timeout: 3_000 });
      } catch {
        await locator.click({ timeout, force: true });
      }
    };
    const back = async () => {
      const b = page.getByRole('button', { name: BACK[g.locale] }).last();
      if ((await b.count()) === 0) return false;
      await tap(b, 5_000).catch((e) => log('back', e.message.split('\n')[0]));
      // Move pointer off the top-left Back button so its tooltip does not
      // linger over the underlying route's Back button or screenshots.
      await page.mouse.move(vp.width - 4, vp.height - 4).catch(() => {});
      await page.waitForTimeout(800);
      return true;
    };
    let inSettings = false;
    // Pushed routes above the shell (Settings = 1, Settings -> About = 2,
    // Labs -> LabGroup = 1).
    let pushed = 0;
    // A modal sheet (the Labs add sheet) closes with Escape, as a keyboard
    // or the system back gesture closes it.
    let sheetOpen = false;
    const closeSheet = async () => {
      if (!sheetOpen) return;
      await page.keyboard.press('Escape');
      await page.waitForTimeout(700);
      sheetOpen = false;
    };
    const pop = async () => {
      if (pushed <= 0) return;
      await back();
      pushed--;
      if (pushed === 0) inSettings = false;
    };
    const popAll = async () => {
      for (let i = 0; i < 6; i++) {
        if ((await page.getByRole('button', { name: BACK[g.locale] }).count()) === 0) break;
        await back();
      }
      pushed = 0;
      inSettings = false;
    };
    const open = async (id) => {
      const { nav, kind } = names[id];
      await closeSheet();
      if (kind === 'settings' && inSettings) {
        while (pushed > 1) await pop();
        await page.waitForTimeout(400);
        return;
      }
      await popAll();
      if (kind === 'tab') {
        await tap(navItem(nav));
      } else if (kind === 'area') {
        const onRail = page.getByRole('button', { name: nav, exact: true }).first();
        if ((await onRail.count()) === 0) {
          await tap(page.getByRole('tab', { name: MORE[g.locale], exact: true }).first());
          await page.waitForTimeout(700);
        }
        await tap(page.getByRole('button', { name: nav, exact: true }).or(page.getByText(nav, { exact: true })).last());
      } else {
        // The top-bar button (a rail also has a Settings item; either opens it).
        await tap(page.getByRole('button', { name: nav, exact: true }).first());
        inSettings = true;
        pushed = 1;
      }
      // Move pointer off nav tabs / top-bar icons so tooltips never linger
      // over screen buttons or screenshots.
      await page.mouse.move(vp.width - 4, vp.height / 2).catch(() => {});
      await page.waitForTimeout(700);
    };
    // Since U039 every screen scrolls wherever the pointer is: its scroll
    // view spans the whole body and only the content is the centred reading
    // column (U036, at most 840 dp). Wheel halfway between the body's left
    // edge (the rail's right edge on a shell screen, the window edge on a
    // pushed page or without a rail) and the content: over the side margin
    // on a wide window, over the 16 dp page padding on a narrow one.
    const bodyLeft = () => (pushed > 0 || vp.width < 840 ? 0 : vp.width >= 1200 ? 257 : 81);
    const marginX = (left) => { const b = bodyLeft(); return Math.max(b + 2, Math.round((b + left) / 2)); };
    const pageX = async () => {
      const b = bodyLeft();
      const xs = await page.evaluate((b) => [...document.querySelectorAll('flt-semantics-host [role="heading"], flt-semantics-host h1, flt-semantics-host h2, flt-semantics-host h3, flt-semantics-host h4, flt-semantics-host h5, flt-semantics-host h6')]
        .map((e) => e.getBoundingClientRect()).filter((r) => r.width > 0 && r.top >= 64 && r.top < window.innerHeight && r.left >= b).map((r) => r.left), b).catch(() => []);
      return xs.length ? marginX(Math.min(...xs)) : b + 6;
    };
    // Left of the screen's heading, in the margin (or the page padding).
    const wheelX = async (id) => {
      if (names[id].kind === 'settings') return pageX();
      const b = await H(names[id].heading).boundingBox().catch(() => null);
      return b ? marginX(b.x) : bodyLeft() + 6;
    };
    const toTop = async (x) => {
      for (let i = 0; i < 8; i++) { await page.mouse.move(x, vp.height / 2); await page.mouse.wheel(0, -3000); await page.waitForTimeout(80); }
      await page.waitForTimeout(400);
    };

    // Wheel at x until [locator] sits inside the viewport (below a top bar,
    // above a bottom bar on touch layouts).
    const reveal = async (locator, x, inSheet = false) => {
      for (let i = 0; i < 60 && (await locator.count()) === 0; i++) {
        await page.mouse.move(x, vp.height / 2);
        await page.mouse.wheel(0, 300);
        await page.waitForTimeout(150);
      }
      for (let i = 0; i < 30; i++) {
        const b = await locator.boundingBox({ timeout: 1_000 }).catch(() => null);
        if (b && b.y >= (inSheet ? 0 : 64) && b.y + b.height <= vp.height - (vp.touch && !inSheet ? 85 : 10)) return true;
        await page.mouse.move(x, vp.height / 2);
        await page.mouse.wheel(0, b ? Math.max(-400, Math.min(400, b.y - vp.height / 3)) : 300);
        await page.waitForTimeout(200);
      }
      return false;
    };
    // The extra cells (Q002/Q003): how each is reached, what it must show
    // (target), what is measured for 2x text (probe) and where to wheel.
    const T = X_TEXT[g.locale];
    let sheetX = 6;
    let labGroupsHeadingSeen = false;
    const xh = (name) => page.getByRole('heading', { name, exact: true }).first();
    const fillInSheet = async (pattern, text, replace = false) => {
      const box = page.getByRole('textbox', { name: pattern }).first();
      await reveal(box, sheetX, true);
      await tap(box);
      await page.waitForTimeout(350);
      if (replace) {
        await page.keyboard.press('ControlOrMeta+A');
        await page.keyboard.press('Backspace');
        await page.waitForTimeout(150);
      }
      await page.keyboard.type(text, { delay: 40 });
      await page.waitForTimeout(150);
    };
    const addLab = async (analyte, value, unit, date) => {
      const add = page.getByRole('button', { name: T.labAdd, exact: true }).first();
      await reveal(add, await wheelX('Labs'));
      await tap(add);
      sheetOpen = true;
      await xh(T.labAddTitle).waitFor({ timeout: 15_000 });
      await page.waitForTimeout(500);
      const b = await xh(T.labAddTitle).boundingBox({ timeout: 2_000 }).catch(() => null);
      sheetX = b ? Math.max(2, b.x - 8) : 6;
      await fillInSheet(T.labAnalyte, analyte);
      await fillInSheet(T.labValue, value);
      await fillInSheet(T.labUnit, unit);
      if (date) await fillInSheet(T.labDate, date, true);
      await tap(page.getByRole('button', { name: T.save, exact: true }).first());
      await xh(T.labAddTitle).waitFor({ state: 'hidden', timeout: 15_000 }).catch(() => {});
      sheetOpen = false;
      await page.waitForTimeout(600);
    };
    const EXTRA = {
      'Labs: add sheet': {
        label: T.labAddTitle,
        target: () => xh(T.labAddTitle),
        sheet: true,
        x: () => sheetX,
        go: async () => {
          await open('Labs');
          await H(names.Labs.heading).waitFor({ timeout: 15_000 });
          // With 2x text on a small phone the button sits below the fold.
          const add = page.getByRole('button', { name: T.labAdd, exact: true }).first();
          await reveal(add, await wheelX('Labs'));
          await tap(add);
          sheetOpen = true;
          await xh(T.labAddTitle).waitFor({ timeout: 15_000 });
          await page.waitForTimeout(600);
          const b = await xh(T.labAddTitle).boundingBox({ timeout: 2_000 }).catch(() => null);
          sheetX = b ? Math.max(2, b.x - 8) : 6;
        },
      },
      'Labs: more from the report': {
        label: T.labInterval,
        target: () => xh(T.labInterval),
        sheet: true,
        x: () => sheetX,
        go: async () => {
          if (!sheetOpen) await EXTRA['Labs: add sheet'].go();
          const more = page.getByRole('button', { name: new RegExp(`^${esc(T.labMore)}`) }).first();
          await reveal(more, sheetX, true);
          if ((await more.getAttribute('aria-expanded').catch(() => null)) !== 'true') await tap(more);
          await page.waitForTimeout(700);
        },
      },
      'Labs: same test over time': {
        label: T.labGroupEvery,
        target: () => xh(T.labGroupEvery),
        x: () => null,
        col: true,
        go: async () => {
          await open('Labs');
          // Previous Labs cells may have scrolled the lazy list past its heading.
          await toTop(vp.touch ? 6 : Math.round(vp.width / 2));
          await H(names.Labs.heading).waitFor({ timeout: 15_000 });
          const lx = await wheelX('Labs');
          const btn = page.getByRole('button', { name: T.labGroupBtn, exact: true }).first();
          if ((await btn.count()) === 0) {
            await addLab('HbA1c', '5,4', '%', '2025-01-10');
            await toTop(lx);
            await addLab('HbA1c', '5,6', '%', '2026-10-03');
          }
          await toTop(lx);
          await reveal(btn, lx);
          labGroupsHeadingSeen = (await xh(T.labGroupsTitle).count()) > 0;
          await tap(btn);
          pushed = 1;
          await xh(T.labGroupTitle).waitFor({ timeout: 15_000 });
          await page.waitForTimeout(600);
        },
      },
      'Labs: field details': {
        label: T.labAnalyteDetails,
        target: () => page.getByText(T.labAnalyteDetails, { exact: true }).or(page.getByLabel(T.labAnalyteDetails, { exact: true })).first(),
        sheet: true,
        x: () => sheetX,
        go: async () => {
          if (!sheetOpen) await EXTRA['Labs: add sheet'].go();
          const t = page.getByRole('button', { name: T.fieldDetailsAnalyte }).first();
          await reveal(t, sheetX, true);
          if ((await t.getAttribute('aria-expanded').catch(() => null)) !== 'true') await tap(t);
          await page.waitForTimeout(700);
        },
      },
      'Medications: I took it': {
        label: T.medsDose,
        target: () => xh(T.medsDose),
        sheet: true,
        x: () => sheetX,
        go: async () => {
          await open('Medications');
          await H(names.Medications.heading).waitFor({ timeout: 15_000 });
          const mx = await wheelX('Medications');
          const took = page.getByRole('button', { name: T.medsTookIt, exact: true }).first();
          if ((await took.count()) === 0) {
            const add = page.getByRole('button', { name: T.medsAdd, exact: true }).first();
            await reveal(add, mx);
            await tap(add);
            sheetOpen = true;
            await xh(T.medsAdd).waitFor({ timeout: 15_000 });
            await page.waitForTimeout(500);
            const b = await xh(T.medsAdd).boundingBox({ timeout: 2_000 }).catch(() => null);
            sheetX = b ? Math.max(2, b.x - 8) : 6;
            await fillInSheet(T.medsName, 'Vitamin D');
            const save = page.getByRole('button', { name: T.save, exact: true }).first();
            await reveal(save, sheetX, true);
            await tap(save);
            await xh(T.medsAdd).waitFor({ state: 'hidden', timeout: 15_000 }).catch(() => {});
            sheetOpen = false;
            await page.waitForTimeout(600);
          }
          await reveal(took, mx);
          await tap(took);
          sheetOpen = true;
          await xh(T.medsDose).waitFor({ timeout: 15_000 });
          await page.waitForTimeout(600);
          const b = await xh(T.medsDose).boundingBox({ timeout: 2_000 }).catch(() => null);
          sheetX = b ? Math.max(2, b.x - 8) : 6;
        },
      },
      'Timeline: record details': {
        label: `${T.enteredOn} …`,
        target: () => page.getByText(new RegExp(`^${esc(T.enteredOn)} `)).first(),
        sheet: true,
        x: () => sheetX,
        go: async () => {
          await open('Timeline');
          await H(names.Timeline.heading).waitFor({ timeout: 15_000 });
          let tx = await wheelX('Timeline');
          // The row is one button whose name starts with the test and value.
          const row = page.getByRole('button', { name: /^HbA1c\s+\d/ }).first();
          if (!(await reveal(row, tx))) {
            // No lab result yet in this page: add one (as a person would).
            await open('Labs');
            await H(names.Labs.heading).waitFor({ timeout: 15_000 });
            await addLab('HbA1c', '5,4', '%', '2025-01-10');
            await open('Timeline');
            await H(names.Timeline.heading).waitFor({ timeout: 15_000 });
            tx = await wheelX('Timeline');
            await reveal(row, tx);
          }
          await tap(row);
          sheetOpen = true;
          await xh(T.versions).waitFor({ timeout: 15_000 });
          await page.waitForTimeout(500);
          const b = await xh(T.versions).boundingBox({ timeout: 2_000 }).catch(() => null);
          sheetX = b ? Math.max(2, b.x - 8) : 6;
          const t = page.getByRole('button', { name: T.detailsToggle }).first();
          await reveal(t, sheetX, true);
          if ((await t.getAttribute('aria-expanded').catch(() => null)) !== 'true') await tap(t);
          await page.waitForTimeout(700);
        },
      },
      'Settings: palettes': {
        label: T.palette,
        target: () => xh(T.palette),
        x: () => null,
        col: true,
        go: async () => { await open('Settings'); await H(names.Settings.heading).waitFor({ timeout: 15_000 }); },
      },
      'Settings: app lock': {
        label: T.lock,
        target: () => xh(T.lock),
        x: () => null,
        col: true,
        go: async () => { await open('Settings'); await H(names.Settings.heading).waitFor({ timeout: 15_000 }); },
      },
      'Settings: about': {
        label: T.aboutBuild,
        target: () => xh(T.aboutBuild),
        x: () => null,
        col: true,
        go: async () => {
          await open('Settings');
          await H(names.Settings.heading).waitFor({ timeout: 15_000 });
          const row = page.getByRole('button', { name: new RegExp(`^${esc(T.about)}`) }).or(page.getByText(T.about, { exact: true })).first();
          await reveal(row, await pageX());
          await tap(row);
          pushed = 2;
          await xh(T.about).waitFor({ timeout: 15_000 });
          await page.waitForTimeout(600);
        },
      },
      'Today: restore from file': {
        label: T.restore,
        target: () => page.getByRole('button', { name: T.restore, exact: true }).first(),
        probe: () => H(names.Today.heading),
        x: () => null,
        go: async () => { await open('Today'); await H(names.Today.heading).waitFor({ timeout: 15_000 }); },
      },
    };

    // Palette groups set the palette through Settings first.
    let paletteApplied = null;
    if (g.palette) {
      try {
        await open('Settings');
        const swatch = page.getByRole('button', { name: g.palette, exact: true }).first();
        for (let i = 0; i < 30; i++) {
          const b = await swatch.boundingBox().catch(() => null);
          if (b && b.y > 60 && b.y + b.height < vp.height - 10) break;
          await page.mouse.move(await pageX(), vp.height / 2);
          await page.mouse.wheel(0, b ? Math.max(-400, Math.min(400, b.y - vp.height / 2)) : 300);
          await page.waitForTimeout(200);
        }
        await tap(swatch);
        await page.waitForTimeout(600);
        // The note under the swatches appears only once a palette other than
        // Standard is chosen.
        const note = page.getByText(new RegExp(`${g.palette} has its own light or dark look`)).or(page.getByLabel(new RegExp(`${g.palette} has its own light or dark look`)));
        await note.first().waitFor({ state: 'attached', timeout: 5_000 }).catch(() => {});
        paletteApplied = (await note.count()) > 0;
        await toTop(await pageX());
      } catch (e) {
        log('palette', e.message.split('\n')[0]);
        paletteApplied = false;
      }
    }

    let first = true;
    for (const id of g.screens) {
      const key = cellId(g, id);
      if (!first) sink = { pageErrors: [], consoleErrors: [], failedRequests: [], overflow: [], flutterErrors: [] };
      first = false;
      const cell = { id: key, variant: g.variant, viewport: g.vp, size: `${vp.width}x${vp.height}`, locale: g.locale, screen: id, checks: {} };
      cells[key] = cell;
      groupKeys.push(key);
      const set = (name, status, detail = '') => { cell.checks[name] = { status, detail }; };
      let reached = false;
      log('cell', key);
      const ex = EXTRA[id];
      let x = 6;
      let probeHeight = null;
      let lockReasonSeen = false;
      try {
        if (ex) {
          await ex.go();
          x = ex.x() ?? (ex.col ? await pageX() : await wheelX('Today'));
          if (ex.probe) { await toTop(x); probeHeight = (await ex.probe().boundingBox({ timeout: 2_000 }).catch(() => null))?.height ?? null; }
          reached = await reveal(ex.target(), x, !!ex.sheet);
          if (!reached) cell.navError = 'target not brought into view';
          // Read while the section is on screen (lazy lists drop it later).
          if (reached && id === 'Settings: app lock') {
            await page.waitForTimeout(300);
            lockReasonSeen = (await page.getByText(T.lockReason, { exact: true }).count()) + (await page.getByLabel(T.lockReason, { exact: true }).count()) > 0;
          }
        } else {
          if (!(g.palette && id === 'Settings' && inSettings)) await open(id);
          await H(names[id].heading).waitFor({ timeout: 15_000 });
          reached = await H(names[id].heading).isVisible();
        }
      } catch (e) {
        cell.navError = e.message.split('\n')[0];
      }
      log('reached', reached, cell.navError ?? '');
      const targetLoc = ex ? ex.target() : H(names[id].heading);
      if (!ex) x = reached ? await wheelX(id) : 6;
      if (!ex && reached && id !== 'Settings') await toTop(x);
      if (mode === 'release') {
        const hb = reached ? await targetLoc.boundingBox({ timeout: 2_000 }).catch(() => null) : null;
        const what = `"${ex ? ex.label : names[id].heading}"`;
        set('heading_visible', reached && hb && hb.y >= 0 && hb.y + hb.height <= vp.height ? 'PASS' : 'FAIL', reached ? what : `${what} not shown${cell.navError ? `: ${cell.navError}` : ''}`);
        if (g.palette) set('palette_applied', paletteApplied ? 'PASS' : 'FAIL', `${g.palette} chosen in Settings`);
        // Compared later: 2× text must really reach the app. Settings' title
        // is in the top bar, whose text Flutter caps at about 1.34×, so the
        // first heading of its content is measured there.
        const probe = id === 'Settings' ? H(SETTINGS_FIRST_HEADING[g.locale]) : null;
        cell.headingHeight = ex?.probe ? probeHeight : probe ? (await probe.boundingBox().catch(() => null))?.height ?? null : hb?.height ?? null;
        const shot = `${g.variant}_${g.vp}_${g.locale}_${id.replace(/[^A-Za-z]+/g, '-')}.png`;
        await page.screenshot({ path: join(out, shot) }).catch(() => {});
        cell.screenshot = shot;
      }
      // Sweep the screen top to bottom: Flutter builds lazy lists only near
      // the viewport and clips semantics rects at the list's edges, so each
      // control is measured at the largest size seen while scrolling.
      const seen = new Map();
      const headingsSeen = new Set();
      const labelsSeen = new Set();
      let hscroll = { max: 0, width: vp.width };
      if (reached && ex) await toTop(x);
      if (reached) {
        let lastSig = '';
        let same = 0;
        for (let i = 0; i < 80; i++) {
          const snap = await page.evaluate(({ TARGET_ROLES, vw, vh }) => {
            const nameOf = (e) => {
              const lab = e.getAttribute('aria-label');
              if (lab && lab.trim()) return lab.trim();
              const by = e.getAttribute('aria-labelledby');
              if (by) { const t = by.split(/\s+/).map((i) => document.getElementById(i)?.textContent ?? '').join(' ').trim(); if (t) return t; }
              return (e.textContent ?? '').replace(/\s+/g, ' ').trim();
            };
            const nodes = [];
            const headings = [];
            const labels = [];
            const visible = [];
            for (const e of document.querySelectorAll('flt-semantics-host [role="heading"], flt-semantics-host h1, flt-semantics-host h2, flt-semantics-host h3, flt-semantics-host h4, flt-semantics-host h5, flt-semantics-host h6')) {
              const n = nameOf(e);
              if (n) headings.push(n);
            }
            for (const e of document.querySelectorAll('flt-semantics-host [aria-label]')) {
              const l = e.getAttribute('aria-label')?.trim();
              if (l) labels.push(l);
            }
            for (const e of document.querySelectorAll('flt-semantics-host flt-semantics')) {
              const n = nameOf(e);
              if (n) labels.push(n);
              const r = e.getBoundingClientRect();
              if (r.width <= 0 || r.height <= 0 || r.bottom <= 0 || r.top >= vh || r.right <= 0 || r.left >= vw) continue;
              if (n) visible.push(`${n.slice(0, 40)}@${Math.round(r.top)}`);
            }
            for (const e of document.querySelectorAll('flt-semantics-host [role], flt-semantics-host a, flt-semantics-host [flt-tappable]')) {
              const role = e.tagName === 'A' ? 'link' : (e.getAttribute('role') ?? '');
              const tappable = e.hasAttribute('flt-tappable');
              if (!TARGET_ROLES.includes(role) && !tappable) continue;
              const r = e.getBoundingClientRect();
              if (r.width <= 0 || r.height <= 0 || r.bottom <= 0 || r.top >= vh || r.right <= 0 || r.left >= vw) continue;
              nodes.push({ role: role || 'tappable', tappable, name: nameOf(e), x: Math.round(r.left), y: Math.round(r.top), w: Math.round(r.width), h: Math.round(r.height), disabled: e.getAttribute('aria-disabled') === 'true' });
            }
            // The page's own horizontal scroll: the document's scroll width
            // and whether the window really moves sideways. (Flutter's body
            // is fixed with overflow hidden, so content clipped inside it is
            // not page scroll.)
            const de = document.documentElement;
            const y = window.scrollY;
            window.scrollTo(100000, y);
            const sx = window.scrollX;
            window.scrollTo(0, y);
            return { nodes, headings, labels, visible, sw: Math.max(de.scrollWidth, window.innerWidth + sx), iw: window.innerWidth };
          }, { TARGET_ROLES, vw: vp.width, vh: vp.height });
          hscroll = { max: Math.max(hscroll.max, snap.sw), width: snap.iw };
          for (const h of snap.headings) headingsSeen.add(h);
          for (const l of snap.labels) labelsSeen.add(l);
          for (const n of snap.nodes) {
            const k = `${n.role}|${n.name}|${n.x}`;
            const prev = seen.get(k);
            if (!prev) seen.set(k, { ...n });
            else { prev.w = Math.max(prev.w, n.w); prev.h = Math.max(prev.h, n.h); }
          }
          const sig = snap.visible.length ? snap.visible.join('|') : snap.nodes.map((n) => `${n.name}@${n.y}`).join('|');
          if (sig === lastSig) { if (++same >= 2) break; } else same = 0;
          lastSig = sig;
          log('sweep', i, snap.nodes.length);
          await page.mouse.move(x, vp.height / 2);
          await page.mouse.wheel(0, Math.round(vp.height * (mode === 'debug' ? 0.65 : 0.3)));
          await page.waitForTimeout(mode === 'debug' ? 300 : 250);
        }
        await toTop(x);
      }
      // The app lock in a development build: the reason is shown and every
      // lock control is disabled (none looks usable).
      if (mode === 'release' && reached && id === 'Settings: app lock') {
        const reason = lockReasonSeen ? 1 : 0;
        const ctl = [...seen.values()].filter((n) => T.lockControls.test(n.name));
        const enabled = ctl.filter((n) => !n.disabled);
        set('lock_state_clear', reason > 0 && ctl.length >= 2 && enabled.length === 0 ? 'PASS' : 'FAIL',
          `reason shown: ${reason > 0}; ${ctl.length} lock controls, ${enabled.length} enabled${enabled.length ? ` (${enabled.map((n) => n.name.slice(0, 30)).join(', ')})` : ''}`);
      }
      // Settings -> About Human OS (U032/Q003): both section titles are
      // standalone headings, not merged with their card bodies.
      if (mode === 'release' && reached && id === 'Settings: about') {
        const hasBuild = headingsSeen.has(T.aboutBuild);
        const hasCaps = headingsSeen.has(T.aboutCaps);
        set('about_sections_clear', hasBuild && hasCaps ? 'PASS' : 'FAIL',
          `headings "${T.aboutBuild}": ${hasBuild}, "${T.aboutCaps}": ${hasCaps}`);
      }
      // Labs -> Same test over time (F004-S4/Q003): the section heading on
      // Labs is its own heading and the chart carries its spoken summary.
      if (mode === 'release' && reached && id === 'Labs: same test over time') {
        const spoken = [...labelsSeen].find((l) => T.labGroupChartSpoken.test(l));
        set('lab_group_chart_spoken', labGroupsHeadingSeen && !!spoken ? 'PASS' : 'FAIL',
          `labs group heading: ${labGroupsHeadingSeen}; spoken chart: ${spoken ? `"${spoken.slice(0, 70)}"` : 'missing'}`);
      }
      // The restore entry opens the system file chooser; a chooser closed
      // without a file says so and changes nothing.
      if (mode === 'release' && reached && id === 'Today: restore from file') {
        try {
          await reveal(ex.target(), x);
          const [chooser] = await Promise.all([page.waitForEvent('filechooser', { timeout: 15_000 }), tap(ex.target())]);
          set('restore_chooser_opens', 'PASS', 'the browser file chooser opened');
          await chooser.setFiles([]);
          const msg = page.getByText(T.noFile, { exact: true }).or(page.getByLabel(T.noFile, { exact: true })).first();
          await msg.waitFor({ state: 'attached', timeout: 15_000 }).catch(() => {});
          // The card's status line sits above the explanation and the entry
          // (it also reports backups and exports); the app scrolls it into
          // view (Q002). Out of view fails, with a screenshot.
          // The app scrolls a new message into view after the frame that
          // shows it; measure once that has settled.
          await page.waitForTimeout(1_000);
          const mb = await msg.boundingBox({ timeout: 1_000 }).catch(() => null);
          const inView = !!mb && mb.y >= 0 && mb.y + mb.height <= vp.height;
          // What the person sees right after closing the chooser.
          if (!inView) {
            cell.screenshotAfter = cell.screenshot.replace(/\.png$/, '_after-cancel.png');
            await page.screenshot({ path: join(out, cell.screenshotAfter) }).catch(() => {});
          }
          // Flutter keeps no semantics for text scrolled out above the list,
          // so look upward from the entry in small steps.
          for (let k = 0; k < 30 && (await msg.count()) === 0; k++) {
            await page.mouse.move(x, vp.height / 2);
            await page.mouse.wheel(0, -200);
            await page.waitForTimeout(250);
          }
          const seenMsg = (await msg.count()) > 0;
          cell.restoreMessageInView = inView;
          set('restore_cancel_reported', seenMsg && inView ? 'PASS' : 'FAIL', seenMsg ? `"${T.noFile}"${inView ? ' (in view)' : ' (NOT in view after 1 s: above the entry, scrolled out; announced as a live region)'}` : 'no message after the chooser closed without a file');
        } catch (e) {
          set('restore_chooser_opens', 'FAIL', e.message.split('\n')[0]);
        }
      }
      await page.waitForTimeout(200);
      if (mode === 'release') {
        set('no_page_errors', sink.pageErrors.length === 0 ? 'PASS' : 'FAIL', sink.pageErrors.slice(0, 3).join(' | '));
        set('no_console_errors', sink.consoleErrors.length === 0 ? 'PASS' : 'FAIL', sink.consoleErrors.slice(0, 3).join(' | '));
        set('no_failed_requests', sink.failedRequests.length === 0 ? 'PASS' : 'FAIL', sink.failedRequests.slice(0, 3).join(' | '));
        if (!reached) {
          for (const c of ['no_horizontal_scroll', 'controls_named', 'touch_targets']) set(c, 'NOT_TESTED', 'screen not reached');
        } else {
          set('no_horizontal_scroll', hscroll.max <= hscroll.width ? 'PASS' : 'FAIL', `scrollWidth ${hscroll.max} vs viewport ${hscroll.width}`);
          const all = [...seen.values()];
          const unnamed = all.filter((n) => NAMED_ROLES.includes(n.role) && !n.name);
          set('controls_named', unnamed.length === 0 ? 'PASS' : 'FAIL', unnamed.length ? `unnamed ${unnamed.map((n) => `${n.role} at ${n.x},${n.y} ${n.w}x${n.h}`).slice(0, 8).join('; ')}` : `${all.filter((n) => NAMED_ROLES.includes(n.role)).length} buttons/links/tabs named`);
          if (vp.touch) {
            // The modal barrier above a sheet (Flutter's "Scrim") is the
            // strip of page left above a sheet, as tall as the sheet leaves
            // it; it is not a control, and the sheet's own Cancel, drag
            // handle and the system back close it (WCAG 2.5.8 equivalent).
            const scrims = all.filter((n) => SCRIM.test(n.name));
            const small = all.filter((n) => !n.disabled && !SCRIM.test(n.name) && (n.w < MIN_TARGET || n.h < MIN_TARGET));
            cell.smallTargets = small;
            set('touch_targets', small.length === 0 ? 'PASS' : 'FAIL', small.length ? small.map((n) => `"${n.name.slice(0, 50) || '(no name)'}" ${n.role} ${n.w}x${n.h}`).slice(0, 12).join('; ') : `${all.length - scrims.length} targets >= ${MIN_TARGET}x${MIN_TARGET}${scrims.length ? ` (modal barrier not counted: ${scrims.map((n) => `${n.w}x${n.h}`).join(', ')})` : ''}`);
          } else {
            set('touch_targets', 'NOT_APPLICABLE', 'desktop pointer viewport');
          }
        }
      } else {
        // Debug pass: Flutter's own overflow and framework error reports.
        if (!reached) {
          set('no_flutter_overflow', 'NOT_TESTED', 'screen not reached in the debug build');
          set('no_flutter_exceptions', 'NOT_TESTED', 'screen not reached in the debug build');
        } else {
          set('no_flutter_overflow', sink.overflow.length === 0 ? 'PASS' : 'FAIL', [...new Set(sink.overflow)].slice(0, 5).join(' | '));
          set('no_flutter_exceptions', sink.flutterErrors.length === 0 ? 'PASS' : 'FAIL', [...new Set(sink.flutterErrors)].slice(0, 3).join(' | '));
        }
      }
    }
    await ctx.close();
    if (cacheFile) {
      const groupCells = Object.fromEntries(groupKeys.map((k) => [k, cells[k]]));
      await writeFile(cacheFile, JSON.stringify({ gitRev, buildHash, browser: browserVersion, cells: groupCells }, null, 2));
    }
    process.stdout.write(`${mode} ${g.variant} ${g.vp} ${g.locale} done\n`);
  }
  server.close();
  return cells;
}

function esc(t) { return t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

const release = await runPass(releaseRoot, 'release');
const debug = debugRoot ? await runPass(debugRoot, 'debug') : null;
await browser.close();

// ---- merge and judge -----------------------------------------------------------
const cells = Object.values(release).map((c) => {
  const d = debug?.[c.id];
  if (d) Object.assign(c.checks, d.checks);
  else {
    c.checks.no_flutter_overflow = { status: 'NOT_TESTED', detail: 'no debug build given (Flutter reports overflow only in debug builds)' };
    c.checks.no_flutter_exceptions = { status: 'NOT_TESTED', detail: 'no debug build given' };
  }
  const st = Object.values(c.checks).map((k) => k.status);
  c.status = st.includes('FAIL') ? 'FAIL' : st.includes('NOT_TESTED') ? 'PASS_WITH_NOT_TESTED' : 'PASS';
  return c;
});
// 2× text cells: the larger text really reached the app (the heading is at
// least 1.6× as tall as on the same screen, size and language at 1×).
for (const c of cells.filter((c) => c.variant.endsWith('text-2x'))) {
  const refVariant = c.variant === 'text-2x' ? 'base' : c.variant.replace(/-text-2x$/, '');
  const ref = cells.find((r) => r.variant === refVariant && r.viewport === c.viewport && r.locale === c.locale && r.screen === c.screen);
  const ratio = ref?.headingHeight && c.headingHeight ? c.headingHeight / ref.headingHeight : null;
  c.checks.text_scaled_2x = ratio == null
    ? { status: 'NOT_TESTED', detail: 'heading not measured at 1× or 2×' }
    : { status: ratio >= 1.6 ? 'PASS' : 'FAIL', detail: `heading height ${ref.headingHeight} → ${c.headingHeight} (×${ratio.toFixed(2)})` };
  const st = Object.values(c.checks).map((k) => k.status);
  c.status = st.includes('FAIL') ? 'FAIL' : st.includes('NOT_TESTED') ? 'PASS_WITH_NOT_TESTED' : 'PASS';
}
const NOT_TESTED_PLATFORMS = [
  'Real Android phones and tablets', 'Real iPhones and iPads (iOS/iPadOS)', 'Windows desktop app', 'macOS desktop app',
  'Firefox', 'Safari', 'Screen readers: TalkBack', 'Screen readers: VoiceOver', 'Screen readers: NVDA',
].map((what) => ({ what, status: 'NOT_TESTED', reason: 'not available in this container' }));

const counts = { cells: cells.length, PASS: cells.filter((c) => c.status === 'PASS').length, FAIL: cells.filter((c) => c.status === 'FAIL').length, PASS_WITH_NOT_TESTED: cells.filter((c) => c.status === 'PASS_WITH_NOT_TESTED').length };
const meta = {
  tool: 'tools/flutter_screen_matrix.mjs',
  ran_at: new Date().toISOString(),
  git_head: gitRev,
  working_tree_dirty: gitDirty,
  browser: `chromium ${browserVersion}`,
  release_build: releaseRoot,
  release_main_dart_js_sha256: await sha256(join(releaseRoot, 'main.dart.js')).catch(() => 'missing'),
  debug_build: debugRoot,
  debug_main_dart_js_sha256: debugRoot ? await sha256(join(debugRoot, 'main.dart.js')).catch(() => 'missing') : null,
  viewports: VIEWPORTS,
  min_touch_target_css_px: MIN_TARGET,
  checks: {
    heading_visible: 'the screen heading (semantics role heading) is on screen',
    palette_applied: 'palette groups only: the palette was chosen through the Settings UI and its note appeared',
    no_page_errors: 'no uncaught page errors while the cell was open (load errors count to the first cell of a page)',
    no_console_errors: 'no console messages of type error',
    no_failed_requests: 'no failed request and no HTTP status >= 400',
    no_horizontal_scroll: 'document scrollWidth <= viewport width at every scroll position',
    controls_named: 'every semantics button, link and tab has a non-empty accessible name',
    touch_targets: `touch viewports: every enabled semantics button/link/tab/checkbox/switch/radio/slider or tappable node is >= ${MIN_TARGET}x${MIN_TARGET} CSS px (largest size seen while scrolling the whole screen); the modal barrier above a sheet ("Scrim") is not counted`,
    no_flutter_overflow: 'debug build of the same revision: the console has no "overflowed by N pixels" report while the screen is opened and scrolled',
    no_flutter_exceptions: 'debug build: no other Flutter framework exception report',
    lock_state_clear: 'Settings: app lock: in a build without an encrypted vault the reason text is shown and every lock control (minute chips, lock-when-hidden switch) is disabled',
    about_sections_clear: 'Settings: about: both section titles ("This build" and "Capabilities on this device", EN/TR) are exposed as standalone headings, not merged with their cards',
    lab_group_chart_spoken: 'Labs: same test over time: "Same test over time" is exposed as its own heading on Labs and the group chart carries its spoken dated-values summary',
    restore_chooser_opens: 'Today: restore from file: tapping the entry opens the browser file chooser',
    restore_cancel_reported: 'Today: restore from file: closing the chooser without a file shows "No file chosen. Nothing was changed." on screen within 1 s',
    text_scaled_2x: '2× text cells only: the heading (on Settings the first content heading; Flutter caps top-bar titles near 1.34×) is at least 1.6× as tall as at 1×, so the setting reached the app',
  },
  counts,
  not_tested: NOT_TESTED_PLATFORMS,
};
await writeFile(join(out, 'matrix.json'), JSON.stringify({ ...meta, cells }, null, 2));

// ---- readable report -------------------------------------------------------------
const label = (s) => (s === 'PASS_WITH_NOT_TESTED' ? 'PASS*' : s);
const md = [];
md.push(`# Screen matrix (Chromium) at ${gitRev.slice(0, 12)}`, '');
md.push(`Tool: \`tools/flutter_screen_matrix.mjs\` · ${meta.ran_at} · chromium ${browserVersion} · working tree dirty: ${gitDirty}`);
md.push(`Release build main.dart.js sha256 \`${meta.release_main_dart_js_sha256}\`${debugRoot ? ` · debug build sha256 \`${meta.debug_main_dart_js_sha256}\`` : ' · no debug build (overflow NOT TESTED)'}`, '');
md.push(`**${counts.cells} cells: ${counts.PASS} PASS, ${counts.FAIL} FAIL${counts.PASS_WITH_NOT_TESTED ? `, ${counts.PASS_WITH_NOT_TESTED} PASS* (a check NOT TESTED)` : ''}.**`, '');
md.push('Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.', '');
const variants = [...new Set(cells.map((c) => c.variant))];
for (const v of variants) {
  const vc = cells.filter((c) => c.variant === v);
  const cols = [...new Set(vc.map((c) => `${c.viewport} ${c.size}|${c.locale}`))];
  const rows = [...new Set(vc.map((c) => c.screen))];
  md.push(`## ${v}`, '');
  md.push(`| Screen | ${cols.map((c) => c.replace('|', ' · ')).join(' | ')} |`);
  md.push(`|---|${cols.map(() => '---').join('|')}|`);
  for (const r of rows) {
    md.push(`| ${r} | ${cols.map((col) => { const c = vc.find((x) => x.screen === r && `${x.viewport} ${x.size}|${x.locale}` === col); return c ? label(c.status) : '–'; }).join(' | ')} |`);
  }
  md.push('');
}
md.push('## FAIL list', '');
const fails = cells.filter((c) => c.status === 'FAIL');
if (!fails.length) md.push('None.');
for (const c of fails) {
  md.push(`- **${c.screen}** · ${c.variant} · ${c.viewport} ${c.size} · ${c.locale} (${c.screenshot})`);
  for (const [k, v] of Object.entries(c.checks)) if (v.status === 'FAIL') md.push(`  - ${k}: ${v.detail}`);
}
md.push('', '## NOT TESTED', '');
md.push('| What | Status | Reason |', '|---|---|---|');
for (const n of NOT_TESTED_PLATFORMS) md.push(`| ${n.what} | NOT TESTED | ${n.reason} |`);
if (!debugRoot) md.push('| Flutter overflow (every cell) | NOT TESTED | no debug build given |');
md.push('');
await writeFile(join(out, 'matrix.md'), md.join('\n'));
console.log(`report: ${out}`);
console.log(`matrix: ${counts.cells} cells, ${counts.PASS} PASS, ${counts.FAIL} FAIL${counts.PASS_WITH_NOT_TESTED ? `, ${counts.PASS_WITH_NOT_TESTED} PASS with a check NOT TESTED` : ''}`);
process.exit(0);
