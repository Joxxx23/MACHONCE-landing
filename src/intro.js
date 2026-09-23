/** @param {HTMLElement} brand @param {HTMLVideoElement} video */
export function startIntro(brand, video) {
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  if (motion.matches || !video.dataset.src) return;

  const mobile = window.matchMedia('(max-width: 600px)').matches;

  const logo = brand.querySelector('.brand__logo');
  const logoReady = logo instanceof HTMLImageElement
    ? logo.decode().catch(() => {})
    : Promise.resolve();
  let finished = false;
  let startTimer = 0;
  let fallbackTimer = 0;
  /** @type {number | null} */
  let frameCallbackId = null;

  function showMobileFrame() {
    if (finished || !mobile) return;
    video.removeEventListener('timeupdate', showMobileFrameAfterTimeUpdate);
    brand.dataset.frame = 'ready';
  }

  function showMobileFrameAfterTimeUpdate() {
    if (video.currentTime > 0 && video.readyState >= 2) showMobileFrame();
  }

  async function showLogo() {
    if (finished) return;
    finished = true;
    window.clearTimeout(startTimer);
    window.clearTimeout(fallbackTimer);
    motion.removeEventListener('change', onMotionChange);
    video.removeEventListener('timeupdate', showMobileFrameAfterTimeUpdate);
    if (frameCallbackId !== null) video.cancelVideoFrameCallback?.(frameCallbackId);
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
    if (!mobile || frameCallbackId !== null || brand.dataset.frame === 'ready') return;

    if (typeof video.requestVideoFrameCallback === 'function') {
      // Safari can briefly clear the video poster when playback starts.
      // Keep the separate image above it until a frame reaches the compositor.
      frameCallbackId = video.requestVideoFrameCallback(showMobileFrame);
    } else {
      // Older browsers: wait for playback progress before exposing the video.
      video.addEventListener('timeupdate', showMobileFrameAfterTimeUpdate);
    }
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
