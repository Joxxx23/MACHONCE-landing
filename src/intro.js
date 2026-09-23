/** @param {HTMLElement} brand @param {HTMLVideoElement} video */
export function startIntro(brand, video) {
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  if (motion.matches || !video.dataset.src) return;

  const logo = brand.querySelector('.brand__logo');
  const logoReady = logo instanceof HTMLImageElement
    ? logo.decode().catch(() => {})
    : Promise.resolve();
  let finished = false;
  let startTimer = 0;
  let fallbackTimer = 0;

  async function showLogo() {
    if (finished) return;
    finished = true;
    window.clearTimeout(startTimer);
    window.clearTimeout(fallbackTimer);
    motion.removeEventListener('change', onMotionChange);
    video.pause();
    // Decode the PNG before uncovering it, so the compositor always has an image.
    await logoReady;

    let released = false;
    function releaseVideo() {
      if (released) return;
      released = true;
      video.removeEventListener('transitionend', releaseVideo);
      video.removeAttribute('src');
      video.load();
    }

    // Keep the video intact until its fade has actually finished.
    video.addEventListener('transitionend', releaseVideo, { once: true });
    brand.dataset.state = 'static';
    // Reduced motion / hidden tabs may not dispatch a transition event.
    window.setTimeout(releaseVideo, 400);
  }

  /** @param {MediaQueryListEvent} event */
  function onMotionChange(event) {
    if (event.matches) showLogo();
  }

  motion.addEventListener('change', onMotionChange);
  video.addEventListener('error', showLogo, { once: true });
  video.addEventListener('ended', showLogo, { once: true });
  video.addEventListener('playing', () => {
    if (finished) {
      video.pause();
      return;
    }
    brand.dataset.state = 'playing';
  });

  brand.dataset.state = 'waiting';
  video.muted = true;
  video.loop = false;
  video.preload = 'auto';
  video.src = video.dataset.src;

  startTimer = window.setTimeout(() => {
    if (finished) return;
    // Covers slow loading, stalled playback, and play() promises that never settle.
    fallbackTimer = window.setTimeout(showLogo, 8000);
    video.play().catch(showLogo);
  }, 1000);
}
