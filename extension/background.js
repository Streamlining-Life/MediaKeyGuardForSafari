// background.js — MV3 service worker. Single job: keep the toolbar button
// honest per tab — coloured when the guard is active on that page, grey when
// the page matches the exclusion list, badged with the sound length when an
// override raises it above the default 5s.
importScripts('matcher.js');

const api = globalThis.browser ?? globalThis.chrome;

const COLOURED = {
  48: 'images/icon-48.png',
  96: 'images/icon-96.png',
  128: 'images/icon-128.png',
};
const GREY = {
  48: 'images/icon-48-grey.png',
  96: 'images/icon-96-grey.png',
  128: 'images/icon-128-grey.png',
};

// Badge APIs are optional in some Safari versions — never let a missing one
// take the icon update down with it, whether it's absent (throws) or present
// but unhappy (rejects).
function quietly(fn) {
  try {
    const r = fn();
    if (r && typeof r.catch === 'function') r.catch(() => {});
  } catch (e) { /* no badge support; icon colour still tells the story */ }
}

function setBadge(tabId, text) {
  quietly(() => api.action.setBadgeText({ tabId, text }));
}

quietly(() => api.action.setBadgeBackgroundColor({ color: '#3a6ea5' }));

// Set the icon (and override badge) for one tab based on its URL vs the lists.
async function refreshTab(tabId, url) {
  if (!url || !/^https?:/.test(url)) return; // ignore internal pages
  const { exclusions, overrides } =
    await api.storage.local.get({ exclusions: [], overrides: [] });
  const excluded = mkgMatcher.isExcluded(url, exclusions);
  // An excluded page runs no guard at all, so its override is moot.
  const threshold = excluded ? null : mkgMatcher.thresholdFor(url, overrides);
  api.action.setIcon({ tabId, path: excluded ? GREY : COLOURED });
  setBadge(tabId, threshold ? `${threshold}s` : '');
}

api.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'loading' || changeInfo.url) refreshTab(tabId, tab.url);
});

api.tabs.onActivated.addListener(async ({ tabId }) => {
  const tab = await api.tabs.get(tabId);
  refreshTab(tabId, tab.url);
});

// A site list changed (popup or options page) — refresh every open tab so
// icons and badges don't lie until the next navigation.
api.storage.onChanged.addListener(async (changes, area) => {
  if (area !== 'local' || (!changes.exclusions && !changes.overrides)) return;
  const tabs = await api.tabs.query({});
  for (const tab of tabs) refreshTab(tab.id, tab.url);
});
