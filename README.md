# Media Key Guard for Safari

Stops short notification sounds from stealing your Mac's media keys away from
Spotify, Music, or whatever you're actually listening to — while leaving real
media (YouTube, podcasts, live streams) fully controllable from the keyboard.

## Problem to solve

macOS hands the play/pause key to whichever app most recently registered a
"Now Playing" session — and Safari registers one for **any** sound a web page
makes, including a two-second Teams ping or a web-mail notification blip. So
you're listening to Spotify, something chirps in a background tab, and now
your play/pause key replays the chirp instead of pausing your music. Safari
has no setting to stop this.

Chrome doesn't have this problem: it treats sounds of **5 seconds or less** as
"transient" and never lets them take over the media keys
([`kMinimumContentDurationSecs`](https://source.chromium.org/chromium/chromium/src/+/main:media/base/media_content_type.cc)).
This extension replicates that rule inside Safari.

## What it does

- A sound of **5 seconds or less** (over-ridable per web-page) finishes playing → the extension releases
  Safari's media-key claim, so the key goes straight back to your music app.
  The sound still plays audibly — nothing is muted or blocked.
- Anything **longer than 5 seconds** (or of unknown/infinite length, e.g. live
  streams) is left completely alone — play/pause keeps controlling it, exactly
  as before.
- Sites whose chimes run longer than 5 seconds can have that limit
  [raised individually](#sites-with-longer-notification-sounds).
- Everything runs locally in your browser. Nothing is collected or sent
  anywhere ([privacy policy](PRIVACY.md)).

## Install

Requires macOS 26 or later.

**From a release:** download the latest app from
[Releases](https://github.com/Streamlining-Life/MediaKeyGuardForSafari/releases),
move it to Applications, open it once, then enable the extension in
**Safari → Settings → Extensions**.

**From source:** see [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

1. Enable **Media Key Guard for Safari** in Safari → Settings → Extensions,
   and allow it on the sites you want protected (or *Always Allow on Every
   Website* — notification sounds can come from anywhere).
2. That's it. Play music, let a notification chirp, press play/pause — your
   music pauses, not the chirp.

### Toolbar icon

| Icon | Meaning |
|------|---------|
| Blue | Guard active on this page |
| Blue + badge (e.g. `12s`) | Guard active, with a raised sound-length limit for this site |
| Grey | This page is excluded — Safari's default behaviour applies here |

### Excluding a site

Click the toolbar icon → **Exclude this site** to give one site its stock
Safari behaviour back (its sounds may steal the media keys again — that's the
point). The popup's **Edit site lists…** opens an editor supporting patterns
at any granularity:

| To exclude… | Pattern |
|---|---|
| One exact page | `teams.microsoft.com/l/meetup-join/abc` |
| A path section | `example.com/mail/*` |
| One subdomain | `mail.example.com/*` |
| Whole domain + subdomains | `*.example.com/*` |

Changes apply on the next page load.

### Sites with longer notification sounds

Some sites use a chime longer than 5 seconds, so the guard reads it as real
media and leaves the keys with it. Raise the limit for just that site: click
the toolbar icon, set the number of seconds, **Apply**, then reload the page.

The same thing by hand, in the options page's second box — the exclusion
patterns above, plus `= seconds`:

```
teams.microsoft.com/* = 12
*.slack.com/* = 10
```

Where several lines match a page, the largest wins. Raise the limit only as
far as the chime needs: real media on that site shorter than the limit — a
voice note, a short clip — will also hand the keys back when it ends.

Sounds of unknown or infinite length (live streams, calls) are unaffected by
this setting; they're always treated as real media.

### Notes

- Pressing play/pause *while* a short sound is still playing pauses that sound
  (Safari owns the key during playback); the key returns to your music as soon
  as the sound finishes.
- Sounds played via `<source>` child elements (rare for notifications) aren't
  handled yet — exclude the site if one misbehaves, and please open an issue.

## Contributing

Forks and pull requests welcome. [CONTRIBUTING.md](CONTRIBUTING.md) takes you
the whole way — fork, build, run your own copy in Safari, open a PR — and
assumes no Xcode or GitHub experience. About half an hour, most of it Xcode
downloading.

## License

[PolyForm Noncommercial 1.0.0](LICENSE.md) — free to use, fork, and modify for
any noncommercial purpose; selling it (or derivatives) isn't permitted.
