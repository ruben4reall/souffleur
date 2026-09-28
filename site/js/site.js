// Souffleur's website: the bar's hairline, the filmed take, the lamp, the stage light chips and the page counter. Everything still
// reads without it.
const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

// Runs `step` every `interval` while `element` is on screen and the page is visible. Returns a function that stops it
// for good.
function whileVisible(element, interval, step) {
  let timer = null;
  let seen = false;
  let cancelled = false;
  const run = () => { if (!cancelled && !timer && seen && !document.hidden) timer = setInterval(step, interval); };
  const halt = () => { clearInterval(timer); timer = null; };
  new IntersectionObserver(([entry]) => { seen = entry.isIntersecting; seen ? run() : halt(); }).observe(element);
  document.addEventListener('visibilitychange', () => (document.hidden ? halt() : run()));
  return () => { cancelled = true; halt(); };
}

(() => {
  // The bar's hairline appears once the page moves: at the top, the prompter hangs from the bar with nothing between.
  const nav = document.querySelector('.nav');
  if (!nav) return;
  const mark = () => nav.classList.toggle('is-scrolled', scrollY > 4);
  addEventListener('scroll', mark, { passive: true });
  mark();
})();

(() => {
  // The filmed take plays while it is on screen; with reduced motion it stays on its poster, with controls.
  const video = document.querySelector('[data-reel]');
  if (!video) return;
  if (still) { video.controls = true; return; }
  new IntersectionObserver(([entry]) => {
    if (entry.isIntersecting) video.play().catch(() => { video.controls = true; });
    else video.pause();
  }, { threshold: 0.35 }).observe(video);
})();

(() => {
  // The lamp over "Invisible when you record" rests while it is off screen.
  const lamp = document.querySelector('[data-lamp]');
  if (!lamp) return;
  new IntersectionObserver(([entry]) => lamp.classList.toggle('is-idle', !entry.isIntersecting)).observe(lamp);
})();

(() => {
  // The cards' gradient borders turn towards the pointer.
  for (const card of document.querySelectorAll('[data-glow]')) {
    card.addEventListener('pointermove', (event) => {
      const box = card.getBoundingClientRect();
      card.style.setProperty('--grad-x', `${((event.clientX - box.left) / box.width) * 100}%`);
      card.style.setProperty('--grad-y', `${((event.clientY - box.top) / box.height) * 100}%`);
    });
  }
})();

(() => {
  // The stage light chips: each colour is its own capture of the app. They take turns until one is chosen.
  const shots = document.querySelector('[data-lights]');
  if (!shots) return;
  const chips = [...document.querySelectorAll('.light-chip')];
  const show = (light) => {
    for (const chip of chips) chip.setAttribute('aria-pressed', String(chip.dataset.light === light));
    for (const image of shots.querySelectorAll('img')) image.classList.toggle('on', image.dataset.light === light);
  };
  let stop = () => {};
  if (!still) {
    let index = 0;
    stop = whileVisible(shots, 2400, () => {
      index = (index + 1) % chips.length;
      show(chips[index].dataset.light);
    });
  }
  for (const chip of chips) {
    chip.addEventListener('click', () => {
      stop();
      stop = () => {};
      show(chip.dataset.light);
    });
  }
})();

(() => {
  // Ruben's own page counter (ruben-analytics): one anonymous page view, no cookie, no identifier, sent only from
  // the published site.
  addEventListener('load', () => {
    if (!location.hostname.endsWith('getsouffleur.vercel.app')) return;
    const endpoint = 'https://ruben-analytics.vercel.app/api/hit';
    const body = JSON.stringify({ site: 'souffleur', path: location.pathname, ref: document.referrer });
    try { if (!navigator.sendBeacon(endpoint, body)) throw new Error('beacon'); }
    catch { fetch(endpoint, { method: 'POST', body, keepalive: true }).catch(() => {}); }
  });
})();
