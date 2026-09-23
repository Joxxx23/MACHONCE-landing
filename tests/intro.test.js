import test from 'node:test';
import assert from 'node:assert/strict';
import { startIntro } from '../src/intro.js';

function createIntro(mobile, videoFrames = true) {
  const timers = [];
  const motion = { matches: false, addEventListener() {}, removeEventListener() {} };
  const previousWindow = globalThis.window;
  const previousImage = globalThis.HTMLImageElement;
  globalThis.HTMLImageElement = class { decode() { return Promise.resolve(); } };
  globalThis.window = {
    matchMedia(query) { return query.includes('max-width') ? { matches: mobile } : motion; },
    setTimeout(callback, delay) { timers.push({ callback, delay }); return timers.length; },
    clearTimeout() {},
  };

  const brand = {
    dataset: { state: 'static' },
    querySelector() { return new globalThis.HTMLImageElement(); },
  };
  class FakeVideo extends EventTarget {
    dataset = { src: '/assets/machonce-intro.mp4' };
    currentTime = 0;
    readyState = 0;
    play() { this.dispatchEvent(new Event('playing')); return Promise.resolve(); }
    pause() {}
    removeAttribute() {}
    load() {}
    requestVideoFrameCallback(callback) { this.frameCallback = callback; return 1; }
    cancelVideoFrameCallback() {}
  }
  const video = new FakeVideo();
  if (!videoFrames) video.requestVideoFrameCallback = undefined;

  return {
    brand, video, timers,
    restore() { globalThis.window = previousWindow; globalThis.HTMLImageElement = previousImage; },
  };
}

test('mobile poster remains until a video frame reaches the compositor', () => {
  const intro = createIntro(true);
  try {
    startIntro(intro.brand, intro.video);
    assert.equal(intro.brand.dataset.state, 'waiting');
    assert.equal(intro.brand.dataset.frame, undefined);
    assert.equal(intro.timers[0].delay, 1000);
    intro.timers[0].callback();
    assert.equal(intro.brand.dataset.state, 'playing');
    assert.equal(intro.brand.dataset.frame, undefined);
    intro.video.frameCallback();
    assert.equal(intro.brand.dataset.frame, 'ready');
  } finally { intro.restore(); }
});

test('mobile fallback waits for playback progress and decoded data', () => {
  const intro = createIntro(true, false);
  try {
    startIntro(intro.brand, intro.video);
    intro.timers[0].callback();
    intro.video.dispatchEvent(new Event('timeupdate'));
    assert.equal(intro.brand.dataset.frame, undefined);
    intro.video.currentTime = 0.05;
    intro.video.readyState = 2;
    intro.video.dispatchEvent(new Event('timeupdate'));
    assert.equal(intro.brand.dataset.frame, 'ready');
  } finally { intro.restore(); }
});

test('desktop playback does not use the mobile frame gate', () => {
  const intro = createIntro(false);
  try {
    startIntro(intro.brand, intro.video);
    intro.timers[0].callback();
    assert.equal(intro.brand.dataset.state, 'playing');
    assert.equal(intro.video.frameCallback, undefined);
    assert.equal(intro.brand.dataset.frame, undefined);
  } finally { intro.restore(); }
});
