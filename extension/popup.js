// popup.js — toolbar popup: shows whether the guard is active on the current
// tab and the sound length it counts as a notification, offers a one-click
// site-wide exclude/re-enable and a site-wide length override, and links to
// the options page and the rendered README on GitHub.
(() => {
  'use strict';
  const api = globalThis.browser ?? globalThis.chrome;
  const DEFAULT_SECS = 5; // must match page.js's DEFAULT_THRESHOLD_SECS
  const stateEl = document.getElementById('state');
  const toggleEl = document.getElementById('toggle');
  const noteEl = document.getElementById('note');
  const limitEl = document.getElementById('limit');
  const secsEl = document.getElementById('secs');
  const applyEl = document.getElementById('apply');
  const clearEl = document.getElementById('clear');

  document.getElementById('version').textContent =
    `v${api.runtime.getManifest().version}`;

  document.getElementById('options').addEventListener('click', (e) => {
    e.preventDefault();
    api.runtime.openOptionsPage();
  });

  // Drop every override line that matches this URL — covers hand-edited
  // entries as well as the auto-filled site-wide one. Comment and malformed
  // lines don't parse, so they're left untouched.
  function withoutOverridesFor(url, overrides) {
    return overrides.filter((line) => {
      const o = mkgMatcher.parseOverride(line);
      return !(o && mkgMatcher.matchesAny(url, [o.pattern]));
    });
  }

  // Render state, toggle button and length override for the active tab's URL.
  async function render() {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    const url = tab && tab.url;
    if (!url || !/^https?:/.test(url)) {
      stateEl.textContent = 'Not applicable on this page';
      stateEl.className = '';
      toggleEl.hidden = true;
      limitEl.hidden = true;
      return;
    }

    const { exclusions, overrides } =
      await api.storage.local.get({ exclusions: [], overrides: [] });
    const excluded = mkgMatcher.isExcluded(url, exclusions);
    const threshold = mkgMatcher.thresholdFor(url, overrides);
    const sitePattern = mkgMatcher.siteWidePattern(url);

    stateEl.textContent = excluded
      ? 'Excluded — Safari default here ❌'
      : `Guard active — sounds up to ${threshold || DEFAULT_SECS}s ✅`;
    stateEl.className = excluded ? 'excluded' : 'active';
    toggleEl.hidden = false;
    toggleEl.textContent = excluded ? 'Re-enable for this site'
                                    : 'Exclude this site';

    toggleEl.onclick = async () => {
      let next;
      if (excluded) {
        // Same idea as the override cleanup: drop every matching pattern.
        next = exclusions.filter((p) => !mkgMatcher.isExcluded(url, [p]));
      } else {
        next = exclusions.concat(sitePattern ? [sitePattern] : []);
      }
      await api.storage.local.set({ exclusions: next });
      noteEl.hidden = false;
      render();
    };

    // The length only matters where the guard actually runs.
    limitEl.hidden = excluded || !sitePattern;
    secsEl.value = threshold || 10;
    clearEl.hidden = !threshold;

    applyEl.onclick = async () => {
      const secs = Number(secsEl.value);
      if (!Number.isFinite(secs) || secs <= 0) return;
      const line = mkgMatcher.siteWideOverride(url, secs);
      const next = withoutOverridesFor(url, overrides).concat(line ? [line] : []);
      await api.storage.local.set({ overrides: next });
      noteEl.hidden = false;
      render();
    };

    clearEl.onclick = async () => {
      await api.storage.local.set({ overrides: withoutOverridesFor(url, overrides) });
      noteEl.hidden = false;
      render();
    };
  }

  render();
})();
