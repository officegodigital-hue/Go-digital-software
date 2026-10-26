{{flutter_js}}
{{flutter_build_config}}

(() => {
  const url = new URL(window.location.href);
  const softwareRendering = url.searchParams.get('softwareRendering') === '1';
  let fallbackScheduled = false;

  // Some browser graphics drivers reject CanvasKit shaders. Retry once using
  // Flutter's CPU renderer, preserving the route and avoiding a reload loop.
  const originalError = console.error;
  console.error = function (...args) {
    originalError.apply(console, args);
    if (softwareRendering || fallbackScheduled) return;
    if (!args.some(value => /shader compilation error/i.test(String(value)))) return;
    fallbackScheduled = true;
    url.searchParams.set('softwareRendering', '1');
    window.setTimeout(() => window.location.replace(url.toString()), 0);
  };

  _flutter.loader.load({
    config: softwareRendering
      ? { renderer: 'canvaskit', canvasKitForceCpuOnly: true }
      : {},
  });
})();
