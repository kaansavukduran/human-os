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
await mkdir(out, { recursive: true });

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
    ['Settings', 'Settings', 'Settings', 'settings'],
  ],
  'tr-TR': [
    ['Today', 'Bugün', 'Bugün', 'tab'],
    ['Timeline', 'Zaman çizelgesi', 'Zaman çizelgesi', 'tab'],
    ['Labs', 'Lab', 'Lab', 'tab'],
    ['Medications', 'İlaçlar', 'İlaçlar ve takviyeler', 'tab'],
    ['Nutrition', 'Beslenme', 'Beslenme', 'area'],
    ['Activity', 'Aktivite', 'Aktivite', 'area'],
    ['Conditions', 'Durumlar', 'Durumlar ve belirtiler', 'area'],
    ['Preventive', 'Koruyucu', 'Aşılar, taramalar, kontroller', 'area'],
    ['Documents', 'Belgeler', 'Belgeler', 'area'],
    ['Settings', 'Ayarlar', 'Ayarlar', 'settings'],
  ],
};
const SETTINGS_FIRST_HEADING = { 'en-US': 'Appearance and accessibility', 'tr-TR': 'Görünüm ve erişilebilirlik' };
const MORE = { 'en-US': 'More', 'tr-TR': 'Diğer' };
// Flutter's back button carries its tooltip twice in the semantics text
// ("Back Back"), so allow the repeat.
const BACK = { 'en-US': /^Back(\s+Back)?$/, 'tr-TR': /^Geri(\s+Geri)?$/ };
const ALL = SCREENS['en-US'].map(([id]) => id);
// One group = one page load; its cells are visited in order.
const GROUPS = [];
for (const vp of Object.keys(VIEWPORTS)) for (const locale of LOCALES) GROUPS.push({ variant: 'base', vp, locale, screens: ALL });
for (const palette of ['Matrix', 'Axolotl', 'Trans']) for (const vp of ['phone', 'desktop']) GROUPS.push({ variant: `palette-${palette.toLowerCase()}`, palette, vp, locale: 'en-US', screens: ['Settings', 'Today'] });
// 2× text through the browser's font size (the root font size Flutter web
// reads as its text scale), as a person with a large browser font gets.
for (const locale of LOCALES) GROUPS.push({ variant: 'text-2x', fontSize: '32px', vp: 'small-phone', locale, screens: ALL });

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

// ---- one pass over every group -----------------------------------------------
const browser = await chromium.launch(process.env.CHROME_EXECUTABLE ? { executablePath: process.env.CHROME_EXECUTABLE } : {});
const browserVersion = browser.version();

const cellId = (g, screen) => `${g.variant}|${g.vp}|${g.locale}|${screen}`;

async function runPass(root, mode) {
  const { server, base } = await serve(root);
  const cells = {};
  for (const g of GROUPS) {
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
    // After a palette change Chromium reports an empty full-window
    // semantics node (pointer-events: auto) above the page, so Playwright's
    // actionability check refuses the click; Flutter hit-tests by position
    // (the event still reaches the flutter-view), so a positional click is
    // what a person's tap does.
    const tap = async (locator, timeout = 10_000) => {
      try {
        await locator.click({ timeout: 3_000 });
      } catch {
        await locator.click({ timeout, force: true });
      }
    };
    const back = async () => {
      const b = page.getByRole('button', { name: BACK[g.locale] }).first();
      if ((await b.count()) > 0) { await tap(b, 5_000).catch((e) => log('back', e.message.split('\n')[0])); await page.waitForTimeout(500); }
    };
    let inSettings = false;
    const open = async (id) => {
      const { nav, kind } = names[id];
      if (inSettings) { await back(); inSettings = false; }
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
      }
      await page.waitForTimeout(700);
    };
    // Wheel over the list padding: left of the heading (inside the content
    // column on every layout), or the page's left gutter on Settings.
    const wheelX = async (id) => {
      if (names[id].kind === 'settings') return 6;
      const b = await H(names[id].heading).boundingBox().catch(() => null);
      return b ? Math.max(2, b.x - 8) : 6;
    };
    const toTop = async (x) => {
      for (let i = 0; i < 8; i++) { await page.mouse.move(x, vp.height / 2); await page.mouse.wheel(0, -3000); await page.waitForTimeout(80); }
      await page.waitForTimeout(400);
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
          await page.mouse.move(6, vp.height / 2);
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
        await toTop(6);
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
      const set = (name, status, detail = '') => { cell.checks[name] = { status, detail }; };
      let reached = false;
      log('cell', key);
      try {
        if (!(g.palette && id === 'Settings' && inSettings)) await open(id);
        await H(names[id].heading).waitFor({ timeout: 15_000 });
        reached = await H(names[id].heading).isVisible();
      } catch (e) {
        cell.navError = e.message.split('\n')[0];
      }
      log('reached', reached, cell.navError ?? '');
      const x = reached ? await wheelX(id) : 6;
      if (reached && id !== 'Settings') await toTop(x);
      if (mode === 'release') {
        const hb = reached ? await H(names[id].heading).boundingBox().catch(() => null) : null;
        set('heading_visible', reached && hb && hb.y >= 0 && hb.y + hb.height <= vp.height ? 'PASS' : 'FAIL', reached ? `"${names[id].heading}"` : `"${names[id].heading}" not shown${cell.navError ? `: ${cell.navError}` : ''}`);
        if (g.palette) set('palette_applied', paletteApplied ? 'PASS' : 'FAIL', `${g.palette} chosen in Settings`);
        // Compared later: 2× text must really reach the app. Settings' title
        // is in the top bar, whose text Flutter caps at about 1.34×, so the
        // first heading of its content is measured there.
        const probe = id === 'Settings' ? H(SETTINGS_FIRST_HEADING[g.locale]) : null;
        cell.headingHeight = probe ? (await probe.boundingBox().catch(() => null))?.height ?? null : hb?.height ?? null;
        const shot = `${g.variant}_${g.vp}_${g.locale}_${id}.png`;
        await page.screenshot({ path: join(out, shot) }).catch(() => {});
        cell.screenshot = shot;
      }
      // Sweep the screen top to bottom: Flutter builds lazy lists only near
      // the viewport and clips semantics rects at the list's edges, so each
      // control is measured at the largest size seen while scrolling.
      const seen = new Map();
      let hscroll = { max: 0, width: vp.width };
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
            return { nodes, sw: Math.max(de.scrollWidth, window.innerWidth + sx), iw: window.innerWidth };
          }, { TARGET_ROLES, vw: vp.width, vh: vp.height });
          hscroll = { max: Math.max(hscroll.max, snap.sw), width: snap.iw };
          for (const n of snap.nodes) {
            const k = `${n.role}|${n.name}|${n.x}`;
            const prev = seen.get(k);
            if (!prev) seen.set(k, { ...n });
            else { prev.w = Math.max(prev.w, n.w); prev.h = Math.max(prev.h, n.h); }
          }
          const sig = snap.nodes.map((n) => `${n.name}@${n.y}`).join('|');
          if (sig === lastSig) { if (++same >= 2) break; } else same = 0;
          lastSig = sig;
          log('sweep', i, snap.nodes.length);
          await page.mouse.move(x, vp.height / 2);
          await page.mouse.wheel(0, Math.round(vp.height * 0.3));
          await page.waitForTimeout(mode === 'debug' ? 450 : 250);
        }
        await toTop(x);
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
            const small = all.filter((n) => !n.disabled && (n.w < MIN_TARGET || n.h < MIN_TARGET));
            cell.smallTargets = small;
            set('touch_targets', small.length === 0 ? 'PASS' : 'FAIL', small.length ? small.map((n) => `"${n.name.slice(0, 50) || '(no name)'}" ${n.role} ${n.w}x${n.h}`).slice(0, 12).join('; ') : `${all.length} targets >= ${MIN_TARGET}x${MIN_TARGET}`);
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
for (const c of cells.filter((c) => c.variant === 'text-2x')) {
  const ref = cells.find((r) => r.variant === 'base' && r.viewport === c.viewport && r.locale === c.locale && r.screen === c.screen);
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

const sha256 = async (f) => createHash('sha256').update(await readFile(f)).digest('hex');
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
    touch_targets: `touch viewports: every enabled semantics button/link/tab/checkbox/switch/radio/slider or tappable node is >= ${MIN_TARGET}x${MIN_TARGET} CSS px (largest size seen while scrolling the whole screen)`,
    no_flutter_overflow: 'debug build of the same revision: the console has no "overflowed by N pixels" report while the screen is opened and scrolled',
    no_flutter_exceptions: 'debug build: no other Flutter framework exception report',
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
