// page.js — main-world script. Implements Chrome's media-key rule in Safari.
//
// Problem: macOS hands the media keys to whichever app last registered a
// Now Playing session, and Safari registers one for ANY audio — including a
// 2-second notification ping — so a blip in a background tab steals the keys
// from Spotify/Music. Chrome only claims the keys for "persistent" content
// (duration unknown or > 5s, media/base/media_content_type.cc); short sounds
// are "transient" and never touch the keys.
//
// Mechanism (validated by harness T4/T8): after a short sound finishes, set
// src='' and call load(). The empty string resolves to the page URL, WebKit
// fails to load it as media, and that ERROR state is what releases Now
// Playing — removeAttribute('src') (clean empty, no error) does NOT release,
// and clearing navigator.mediaSession alone does NOT work either (harness
// T3). The original src is parked and restored on the element's next play()
// call, so sites that reuse one <audio> element for every notification keep
// working.
(() => {
  'use strict';
  if (window.__mediaKeyGuard) return; // double-injection guard

  // Chrome parity: kMinimumContentDurationSecs = 5.
  // duration <= 5s  -> transient blip, release the keys after it ends.
  // duration  > 5s, unknown, or Infinity (live stream) -> real content, untouched.
  //
  // Sites whose notification sounds run longer than 5s can raise the bar via
  // the override list; content.js puts the value on the injecting <script>
  // tag's dataset, which is the only channel into this world (an isolated
  // world can't set a main-world global, and an inline script dies under a
  // strict CSP). currentScript is still valid here — this IIFE runs during
  // the tag's synchronous evaluation, before content.js removes it on load.
  const DEFAULT_THRESHOLD_SECS = 5;
  const override = parseFloat(
    (document.currentScript && document.currentScript.dataset.threshold) || ''
  );
  const THRESHOLD_SECS = Number.isFinite(override) && override > 0
    ? override
    : DEFAULT_THRESHOLD_SECS;

  // Doubles as the double-injection flag above. Holding the number rather
  // than `true` lets the harness show which threshold actually landed.
  window.__mediaKeyGuard = THRESHOLD_SECS;

  const watched = new WeakSet();   // elements we've attached an ended-listener to
  const parkedSrc = new WeakMap(); // element -> src we stripped, awaiting restore

  function isBlip(el) {
    const d = el.duration;
    return isFinite(d) && d > 0 && d <= THRESHOLD_SECS && !el.loop;
  }

  // Tear down a finished blip so WebKit gives Now Playing back to the last
  // real media app. Never throw into the host page.
  function release(el) {
    try {
      const src = el.getAttribute('src');
      if (src === null || src === '') return; // <source>-children element; can't park safely — skip
      parkedSrc.set(el, src);
      el.src = '';   // resolves to page URL -> media load error -> Now Playing released
      el.load();
      if (navigator.mediaSession) {
        navigator.mediaSession.playbackState = 'none';
        navigator.mediaSession.metadata = null;
      }
    } catch (e) { /* guard must never break the page */ }
  }

  // Put a parked src back just before the site replays the element.
  function restore(el) {
    try {
      if (!parkedSrc.has(el)) return;
      el.setAttribute('src', parkedSrc.get(el));
      parkedSrc.delete(el);
      el.load();
    } catch (e) { /* ditto */ }
  }

  function watch(el) {
    if (watched.has(el)) return;
    watched.add(el);
    el.addEventListener('ended', () => { if (isBlip(el)) release(el); });
  }

  // Route 1: anything played via the play() method (covers detached
  // `new Audio()` elements — the usual notification pattern).
  const origPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    restore(this);
    watch(this);
    return origPlay.apply(this, args);
  };

  // Route 2: `new Audio()` watched from birth, so autoplay-property playback
  // (no play() call) is still caught.
  const OrigAudio = window.Audio;
  if (OrigAudio) {
    const PatchedAudio = function (...args) {
      const el = new OrigAudio(...args);
      watch(el);
      return el;
    };
    PatchedAudio.prototype = OrigAudio.prototype;
    window.Audio = PatchedAudio;
  }

  // Route 3: DOM-attached elements that autoplay via attribute. 'ended'
  // doesn't bubble but IS seen by capture-phase listeners on the document.
  document.addEventListener('ended', (e) => {
    const el = e.target;
    if (el instanceof HTMLMediaElement && isBlip(el)) release(el);
  }, true);
})();
