// content.js — runs in Safari's isolated content-script world (the only
// world with browser.* APIs). matcher.js is loaded before this file by the
// manifest's content_scripts list.
//
// Job: check the exclusion list, and unless this page is excluded, inject
// page.js into the main world — carrying this page's sound-length threshold
// if the override list sets one. The actual logic must live in the page's
// main world (it patches HTMLMediaElement.prototype, which isolated worlds
// can't share), so injection happens via a real <script> element.
//
// Race note: the storage read and script-src load are async, so a page
// script could in theory play a sound before our patch lands. In practice
// notification blips fire long after page load, so the window is irrelevant —
// the patch just has to exist before the *sound*, not before the page's
// first script. List edits take effect on the next page load.
(() => {
  'use strict';
  const api = globalThis.browser ?? globalThis.chrome;

  // threshold: seconds from the override list, or null for page.js's default.
  function inject(threshold) {
    const s = document.createElement('script');
    s.src = api.runtime.getURL('page.js');
    if (threshold) s.dataset.threshold = String(threshold);
    s.onload = () => s.remove(); // patch installed; tag itself no longer needed
    (document.head || document.documentElement).prepend(s);
  }

  api.storage.local.get({ exclusions: [], overrides: [] })
    .then(({ exclusions, overrides }) => {
      if (globalThis.mkgMatcher.isExcluded(location.href, exclusions)) return;
      inject(globalThis.mkgMatcher.thresholdFor(location.href, overrides));
    })
    .catch(() => {
      // Storage unavailable (shouldn't happen) — fail OPEN: protection matters
      // more than honouring the lists, so inject with the default threshold.
      inject(null);
    });
})();
