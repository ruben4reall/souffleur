// Souffleur's website: a live clock in the menu bar, the reading reel, the spotlight, the stage light chips and the
// page counter. Everything still reads without it.
const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

(() => {
  // The menu bar's clock, like the Mac's: "Sun Sep 27 9:41 PM".
  const clock = document.querySelector('[data-clock]');
  if (!clock) return;
  const day = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  const time = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' });
  const tick = () => {
    const now = new Date();
    clock.textContent = `${day.format(now).replace(',', '')} ${time.format(now)}`;
  };
  tick();
  setInterval(tick, 15000);
})();

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
  // The spotlight follows the pointer over the title; without a pointer it roams on its own (CSS).
  const title = document.querySelector('[data-spotlight]');
  if (!title) return;
  const lit = title.querySelector('.spotlight-lit');
  title.closest('section').addEventListener('pointermove', (event) => {
    const box = title.getBoundingClientRect();
    lit.style.setProperty('--mouse-x', `${((event.clientX - box.left) / box.width) * 100}%`);
    lit.style.setProperty('--mouse-y', `${((event.clientY - box.top) / box.height) * 100}%`);
  });
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
