import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

// Resolve through the installed Pi, just as its extension loader does.
let packageDir = process.env.PI_FOOTER_TEST_PACKAGE_DIR;
if (!packageDir) {
  const npmRoot = execFileSync('npm', ['root', '-g'], { encoding: 'utf8' }).trim();
  packageDir = `${npmRoot}/@earendil-works/pi-coding-agent`;
  if (!existsSync(`${packageDir}/package.json`)) {
    const prefix = execFileSync('brew', ['--prefix', 'pi-coding-agent'], { encoding: 'utf8' }).trim();
    packageDir = `${prefix}/libexec/lib/node_modules/@earendil-works/pi-coding-agent`;
  }
}
const require = createRequire(`${packageDir}/package.json`);
const { createJiti } = require('jiti');
const tuiPath = require.resolve('@earendil-works/pi-tui');
const { visibleWidth } = await import(tuiPath);
const file = path.resolve(import.meta.dirname, '../home/.pi/agent/extensions/fm-quota-footer.ts');
const fixtureDir = mkdtempSync(path.join(tmpdir(), 'pi-footer-'));
const oldPath = process.env.PATH;
process.env.PATH = `${fixtureDir}:${oldPath}`;
writeFileSync(path.join(fixtureDir, 'quota-axi'), '#!/bin/sh\nprintf "%s" "$FOOTER_QUOTA_FIXTURE"\n', { mode: 0o755 });
process.on('exit', () => rmSync(fixtureDir, { recursive: true, force: true }));

async function mount(t, { provider = 'openai-codex', mode = 'tui', stale = false, malformed = false } = {}) {
  process.env.FOOTER_QUOTA_FIXTURE = JSON.stringify({ providers: [
    { provider: 'claude', windows: [{ id: 'five_hour', percentRemaining: 99 }], state: { status: 'fresh', stale: false } },
    { provider: 'codex', windows: [{ id: 'weekly', label: 'week', percentRemaining: 60, resetsAt: new Date(Date.now() + 7200000).toISOString() }], state: { status: stale ? 'stale' : 'fresh', stale } },
  ] });
  if (malformed) process.env.FOOTER_QUOTA_FIXTURE = '{broken';
  const jiti = createJiti(import.meta.url, { moduleCache: false, alias: { '@earendil-works/pi-tui': tuiPath } });
  const extension = await jiti.import(file, { default: true });
  const handlers = new Map();
  let component;
  let thinking = 'high';
  let usage = { tokens: 25000, contextWindow: 100000, percent: 25 };
  let renders = 0;
  let branchListener;
  const ctx = {
    mode, hasUI: mode === 'tui', cwd: '/work/project', model: { id: 'gpt-test', provider, contextWindow: 100000 },
    getContextUsage: () => usage,
    ui: { setFooter: (factory) => { component = factory({ requestRender: () => renders++ }, { fg: (_color, text) => text }, {
      getGitBranch: () => 'feature/footer', getExtensionStatuses: () => new Map([['warning', 'Memory offline']]),
      onBranchChange: (listener) => { branchListener = listener; return () => { branchListener = undefined; }; },
    }); } },
  };
  extension({ on: (name, handler) => handlers.set(name, handler), getThinkingLevel: () => thinking });
  t.after(() => { component?.dispose?.(); handlers.get('session_shutdown')?.({}, ctx); });
  await handlers.get('session_start')({}, ctx);
  // Wait for the real subprocess boundary and its render notification.
  if (mode === 'tui') {
    for (let i = 0; i < 100 && renders === 0; i++) await new Promise(r => setTimeout(r, 5));
  }
  return { ctx, handlers, render: (w = 160) => component?.render(w).join('\n'), setThinking: x => { thinking = x; }, setUsage: x => { usage = x; }, renders: () => renders, branchChanged: () => branchListener?.() };
}

test('context uses the public percentage and tolerates unknown post-compaction usage', async t => {
  const f = await mount(t);
  assert.match(f.render(), /ctx 25%/);
  f.setUsage({ tokens: null, contextWindow: 100000, percent: null });
  assert.match(f.render(), /ctx \?/);
});
test('reasoning follows the live Pi setting, not the startup environment', async t => {
  const f = await mount(t);
  assert.match(f.render(), /high/);
  f.setThinking('low');
  assert.match(f.render(), /low/);
  assert.doesNotMatch(f.render(), /high/);
});
test('quota matches provider aliases and only shows available windows with explicit remaining semantics', async t => {
  const f = await mount(t);
  assert.match(f.render(), /week 60% left/);
  assert.match(f.render(), /reset 2h/);
  assert.doesNotMatch(f.render(), /99%|5h/);
});
test('an unsupported provider never borrows another provider quota', async t => {
  const f = await mount(t, { provider: 'custom-api' });
  assert.doesNotMatch(f.render(), /60%|99%|5h|week/);
});
test('stale quota is not presented as fresh remaining capacity', async t => {
  const f = await mount(t, { stale: true });
  assert.doesNotMatch(f.render(), /60% left/);
  assert.match(f.render(), /quota.*stale/);
});
test('git and extension statuses survive replacement, and narrow rendering preserves context', async t => {
  const f = await mount(t);
  assert.match(f.render(), /feature\/footer/);
  assert.match(f.render(), /Memory offline/);
  const before = f.renders();
  f.branchChanged();
  assert.ok(f.renders() > before);
  for (const width of [0, 1, 20, 40, 80, 160]) {
    const lines = f.render(width).split('\n');
    for (const line of lines) assert.ok(visibleWidth(line) <= width);
    if (width === 40) assert.match(lines[0], /ctx 25%/);
  }
});
test('a model-provider switch immediately removes old quota and fetches the new provider', async t => {
  const f = await mount(t);
  f.ctx.model = { ...f.ctx.model, provider: 'anthropic', id: 'claude-test' };
  f.handlers.get('model_select')({}, f.ctx);
  assert.doesNotMatch(f.render(), /60%/);
  for (let i = 0; i < 100 && !f.render().includes('99%'); i++) await new Promise(r => setTimeout(r, 5));
  assert.match(f.render(), /5h 99% left/);
  assert.doesNotMatch(f.render(), /week/);
});
test('malformed quota output degrades to unavailable rather than crashing', async t => {
  const f = await mount(t, { malformed: true });
  assert.match(f.render(), /quota unavailable/);
  assert.match(f.render(), /ctx 25%/);
});
test('non-TUI sessions do not start a footer', async t => {
  const f = await mount(t, { mode: 'print' });
  assert.equal(f.render(), undefined);
});
