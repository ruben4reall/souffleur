/* Souffleur website. On the hero's screen the prompter reads its own script: real captures of the app, taken a few
   words apart, follow each other like the text scrolling in the notch; a chip shows another state and stops the tour.
   Everything is readable without this script. */
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  for (const mac of document.querySelectorAll('[data-mac]')) mac.setAttribute('data-lid', 'still');

  const stage = document.querySelector('[data-demo]');
  const frames = [...document.querySelectorAll('[data-demo] .shot[data-frame]')];
  const shots = [...document.querySelectorAll('[data-demo] .shot[data-state]')];
  const chips = [...document.querySelectorAll('.demo-chips .chip')];
  const caption = document.querySelector('.demo-caption');
  if (!stage || !chips.length) return;

  let frame = 0;
  let reading = null;
  let tour = null;
  let current = 0;

  const read = (on) => {
    clearInterval(reading);
    reading = null;
    if (!on) return;
    stage.dataset.live = 'read';
    if (reduce) return;
    reading = setInterval(() => {
      frames[frame].classList.remove('on');
      frame = (frame + 1) % frames.length;
      frames[frame].classList.add('on');
    }, 1150);
  };

  const show = (i) => {
    current = i;
    const state = chips[i].dataset.state;
    chips.forEach((chip, j) => chip.setAttribute('aria-pressed', String(j === i)));
    if (caption) caption.textContent = chips[i].dataset.caption;
    if (state === 'read') {
      shots.forEach((shot) => shot.classList.remove('on'));
      read(true);
    } else {
      read(false);
      stage.dataset.live = 'state';
      shots.forEach((shot) => shot.classList.toggle('on', shot.dataset.state === state));
    }
  };

  // The tour: the read-along for a while, then each state, and back.
  const start = () => {
    if (reduce || tour) return;
    read(true);
    tour = setInterval(() => show((current + 1) % chips.length), 7000);
  };
  chips.forEach((chip, i) => chip.addEventListener('click', () => {
    clearInterval(tour);
    tour = -1;
    show(i);
  }));
  new IntersectionObserver(([entry]) => {
    if (tour === -1) return;
    if (entry.isIntersecting) start();
    else { clearInterval(tour); tour = null; read(false); }
  }).observe(stage);
  document.addEventListener('visibilitychange', () => {
    if (tour === -1) return;
    if (document.hidden) { clearInterval(tour); tour = null; read(false); } else start();
  });
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
