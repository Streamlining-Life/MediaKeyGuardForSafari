// options.js — editor for both site lists (exclusions, and the per-site
// sound-length overrides): load each into its textarea, validate every line
// on save, persist to storage.local (background.js live-updates tab icons and
// badges via its storage.onChanged listener).
(() => {
  'use strict';
  const api = globalThis.browser ?? globalThis.chrome;
  const listEl = document.getElementById('list');
  const overridesEl = document.getElementById('overrides');
  const msgEl = document.getElementById('msg');

  api.storage.local.get({ exclusions: [], overrides: [] })
    .then(({ exclusions, overrides }) => {
      listEl.value = exclusions.join('\n');
      overridesEl.value = overrides.join('\n');
    });

  const readLines = (el) => el.value.split('\n').map((l) => l.trim()).filter(Boolean);

  // Comments are kept in the stored lists (the matcher skips them);
  // everything else must parse. Returns the first bad line, or null.
  function firstInvalid(lines, isValid) {
    return lines.find((l) => !l.startsWith('#') && !isValid(l)) || null;
  }

  document.getElementById('save').addEventListener('click', async () => {
    const exclusions = readLines(listEl);
    const overrides = readLines(overridesEl);

    const badPattern = firstInvalid(exclusions, mkgMatcher.isValidPattern);
    if (badPattern) {
      msgEl.textContent = `Invalid pattern: ${badPattern}`;
      msgEl.className = 'err';
      return;
    }
    const badOverride = firstInvalid(overrides, mkgMatcher.isValidOverride);
    if (badOverride) {
      msgEl.textContent = `Invalid override (need "pattern = seconds"): ${badOverride}`;
      msgEl.className = 'err';
      return;
    }

    await api.storage.local.set({ exclusions, overrides });
    msgEl.textContent = 'Saved ✓';
    msgEl.className = 'ok';
  });
})();
