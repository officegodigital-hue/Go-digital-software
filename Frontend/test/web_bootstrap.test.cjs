const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('web entry loads Flutter only once with or without Maps', async () => {
  const html = fs.readFileSync(path.join(__dirname, '../web/index.html'), 'utf8');
  assert.doesNotMatch(html, /<script[^>]+src=["']flutter_bootstrap\.js/);
  const source = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
  for (const mapsEnabled of [false, true]) {
    const scripts = [];
    let maps;
    const context = {
      window: {location: {hostname: 'localhost'}},
      fetch: () => Promise.resolve({
        ok: mapsEnabled,
        text: () => Promise.resolve(
          mapsEnabled ? "window.googleMapsApiKey = 'test-key';" : '',
        ),
      }),
      document: {
        createElement: () => ({}),
        body: {appendChild: script => scripts.push(script)},
        head: {appendChild: script => { maps = script; }},
      },
    };
    vm.runInNewContext(source, context);
    await new Promise(resolve => setImmediate(resolve));
    if (mapsEnabled) { maps.onload(); maps.onerror(); }
    context.startFlutter();
    assert.equal(scripts.length, 1);
    assert.equal(scripts[0].src, 'flutter_bootstrap.js');
  }
});

function bootstrap(href) {
  const loads = [], replacements = [], timers = [];
  const source = fs.readFileSync(path.join(__dirname, '../web/flutter_bootstrap.js'), 'utf8')
    .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
  const context = {
    URL,
    console: {error: () => {}},
    window: {location: {href, replace: value => replacements.push(value)}, setTimeout: fn => timers.push(fn)},
    _flutter: {loader: {load: options => loads.push(options)}},
  };
  vm.runInNewContext(source, context);
  return {context, loads, replacements, timers};
}

test('shader errors trigger only one software-rendering reload and retain the route', () => {
  const app = bootstrap('http://localhost:8080/?example=1#/admin/dashboard');
  assert.equal(app.loads[0].config.canvasKitForceCpuOnly, undefined);
  app.context.console.error('An unrelated error');
  assert.equal(app.timers.length, 0);
  app.context.console.error('Shader compilation error');
  app.context.console.error('Shader compilation error');
  assert.equal(app.timers.length, 1);
  app.timers[0]();
  const url = new URL(app.replacements[0]);
  assert.equal(url.searchParams.get('softwareRendering'), '1');
  assert.equal(url.searchParams.get('example'), '1');
  assert.equal(url.hash, '#/admin/dashboard');
});

test('software renderer bypasses WebGL and cannot cause a reload loop', () => {
  const app = bootstrap('http://localhost:8080/?softwareRendering=1#/admin/payroll');
  assert.equal(app.loads[0].config.renderer, 'canvaskit');
  assert.equal(app.loads[0].config.canvasKitForceCpuOnly, true);
  app.context.console.error('Shader compilation error');
  assert.equal(app.timers.length, 0);
});
