// matcher.js — pattern matching for both site lists, shared by content.js
// (loaded before it in the manifest's content_scripts list) and background.js
// (importScripts). Exposes a single global: mkgMatcher.
//
// Pattern grammar (documented in the options page and README):
//   host[/path]   with `*` wildcards at each level
//     teams.microsoft.com/l/meetup-join/abc   exact page
//     example.com/mail/*                      path section
//     mail.example.com/*                      one subdomain
//     *.example.com/*                         whole domain + all subdomains
//   No path part means "/*" (whole host). Scheme and port are ignored.
//
// Two lists use that grammar:
//   exclusions — bare patterns; matching pages get stock Safari behaviour.
//   overrides  — "pattern = seconds"; matching pages treat sounds up to that
//                length as transient instead of the default 5s.
//
// Deliberately NOT RegExp: `*` is the only wildcard, so a pattern can't
// silently over-match the way a stray regex dot can.
(() => {
  'use strict';

  // Convert one pattern into a case-insensitive anchored RegExp, or null if
  // the pattern is unusable. `*` -> ".*", everything else escaped literally.
  function compile(pattern) {
    const p = pattern.trim().toLowerCase();
    if (!p || p.startsWith('#')) return null; // blank / comment line
    const [host, ...pathParts] = p.split('/');
    if (!host) return null;
    let path = pathParts.join('/');
    if (path === '') path = '*'; // bare host means the whole site
    const esc = (s) => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
    // `*.example.com` should also match the bare apex `example.com`.
    const hostRe = host.startsWith('*.')
      ? `(.*\\.)?${esc(host.slice(2))}`
      : esc(host);
    try {
      return new RegExp(`^${hostRe}/${esc(path)}$`, 'i');
    } catch {
      return null;
    }
  }

  // True if url (a full URL string) matches any pattern in the list.
  function matchesAny(url, patterns) {
    let target;
    try {
      const u = new URL(url);
      // Canonical "host/path" with no trailing slash; query/hash ignored.
      target = u.hostname + u.pathname.replace(/\/$/, '');
    } catch {
      return false;
    }
    return (patterns || []).some((p) => {
      const re = compile(p);
      // Test with a trailing slash too so `host/*` patterns match the site
      // root ("example.com" alone has no "/" for the wildcard to bite on).
      return re ? re.test(target) || re.test(target + '/') : false;
    });
  }

  // Same test, named for the exclusion list's callers.
  const isExcluded = matchesAny;

  // Whole-site pattern for a URL — what the popup's Exclude button auto-fills.
  function siteWidePattern(url) {
    try {
      return `*.${new URL(url).hostname.replace(/^www\./, '')}/*`;
    } catch {
      return null;
    }
  }

  // True if a pattern line is syntactically usable (options page validation).
  function isValidPattern(pattern) {
    return compile(pattern) !== null;
  }

  // --- Overrides: "pattern = seconds" --------------------------------------

  // Parse one override line into { pattern, secs }, or null if unusable.
  // Split on the LAST '=' so a pattern containing one still parses, and allow
  // a trailing "s" on the number ("= 10s") because people write it that way.
  function parseOverride(line) {
    const raw = String(line).trim();
    if (!raw || raw.startsWith('#')) return null; // blank / comment line
    const eq = raw.lastIndexOf('=');
    if (eq === -1) return null;
    const pattern = raw.slice(0, eq).trim();
    const secs = Number(raw.slice(eq + 1).trim().replace(/s$/i, ''));
    if (!pattern || !compile(pattern)) return null;
    if (!Number.isFinite(secs) || secs <= 0) return null;
    return { pattern, secs };
  }

  // Sound length to treat as transient on this URL, or null if no override
  // matches (caller falls back to the built-in 5s). Highest match wins, so a
  // broad line can never shadow a more generous specific one and list order
  // stays irrelevant — same as the exclusion list.
  function thresholdFor(url, overrides) {
    let best = null;
    for (const line of overrides || []) {
      const o = parseOverride(line);
      if (!o || !matchesAny(url, [o.pattern])) continue;
      if (best === null || o.secs > best) best = o.secs;
    }
    return best;
  }

  // True if an override line is syntactically usable (options page validation).
  function isValidOverride(line) {
    return parseOverride(line) !== null;
  }

  // Override line the popup writes for a whole site.
  function siteWideOverride(url, secs) {
    const p = siteWidePattern(url);
    return p ? `${p} = ${secs}` : null;
  }

  const api = {
    isExcluded,
    matchesAny,
    siteWidePattern,
    isValidPattern,
    parseOverride,
    thresholdFor,
    isValidOverride,
    siteWideOverride,
  };
  // Works in content scripts (window) and the background worker (self).
  (typeof self !== 'undefined' ? self : window).mkgMatcher = api;
})();
