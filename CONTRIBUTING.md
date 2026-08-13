# Contributing

This is a small extension. If something annoys you about it, fixing it
yourself is usually faster than waiting for someone else to — and this page
takes you the whole way: **fork → build → run your copy in Safari → change it
→ open a PR → merged and shipped**, with nothing left for you to maintain
afterwards.

No Xcode experience needed. No GitHub experience needed. It's about half an
hour the first time, most of which is Xcode downloading.

**Contents**

- [Part 1 — From nothing to your own build running in Safari](#part-1--from-nothing-to-your-own-build-running-in-safari)
- [Part 2 — Making a change](#part-2--making-a-change)
- [Part 3 — Getting it merged](#part-3--getting-it-merged)
- [Part 4 — Reference](#part-4--reference)

---

# Part 1 — From nothing to your own build running in Safari

## What you need

| | |
|---|---|
| **macOS 26 or later** | The project targets macOS 26. Earlier versions won't build or run it. |
| **Xcode 26 or later** | Free from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835). It's a multi-gigabyte download — **start it now** and read the rest while it lands. |
| **An Apple ID** | The free tier is fine. No paid Developer Program membership required. One caveat, in [step 7](#7-turn-it-on-in-safari). |
| **A GitHub account** | Free. [Sign up](https://github.com/signup) if you don't have one. |

Optional, and only for the checks in [Part 2](#part-2--making-a-change):
Python 3 (ships with Xcode's command-line tools) and Node.

## 1. Fork the repo

A **fork** is your own copy of the project on GitHub. You push to your fork;
the maintainer pulls from it. You never need write access to the original.

Go to
[github.com/Streamlining-Life/MediaKeyGuardForSafari](https://github.com/Streamlining-Life/MediaKeyGuardForSafari)
and click **Fork** (top right) → **Create fork**. You now have
`github.com/YOUR-USERNAME/MediaKeyGuardForSafari`.

If you're fixing something non-obvious, or adding a feature, it's worth
[opening an issue](https://github.com/Streamlining-Life/MediaKeyGuardForSafari/issues)
first to check the approach is wanted — cheaper than writing code nobody
merges.

## 2. Set up your Mac

**Install Xcode** from the App Store, then open it once and accept the
licence. It'll install some extra components on first launch; let it finish.

**Get the command-line tools** (this is where `git` comes from). In Terminal:

```bash
git --version
```

If macOS offers to install the command-line developer tools, accept, wait, and
run it again. A version number means you're set.

**Tell git who you are** — this is what shows up as the commit author:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**Let your Mac push to GitHub.** GitHub stopped accepting passwords over
HTTPS, so you need a key. This takes two minutes and you never do it again:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

Press Return at every prompt (default location, no passphrase, or set one if
you prefer). Then copy the **public** key to your clipboard:

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

Go to [github.com/settings/keys](https://github.com/settings/keys) → **New SSH
key**, give it any title, paste, save. Check it took:

```bash
ssh -T git@github.com
```

Type `yes` at the fingerprint prompt. "Hi USERNAME! You've successfully
authenticated" means done — the "does not provide shell access" bit that
follows is expected.

## 3. Clone your fork

Cloning downloads your fork to your Mac. Substitute your own username:

```bash
git clone git@github.com:YOUR-USERNAME/MediaKeyGuardForSafari.git
cd MediaKeyGuardForSafari
```

Add the original repo as a second remote called `upstream`, so you can pull in
other people's changes later:

```bash
git remote add upstream https://github.com/Streamlining-Life/MediaKeyGuardForSafari.git
```

Two remotes now: `origin` is your fork (you push there), `upstream` is the
original (you only ever read from it).

## 4. Open it in Xcode

```bash
open app/MediaKeyGuardForSafari/MediaKeyGuardForSafari.xcodeproj
```

**Some files are red in the sidebar. That's normal on a fresh clone** — the
extension's `Resources` entries are build artifacts copied from `extension/`
by a build phase, and that hasn't run yet. The first build creates them and
the red clears. Don't try to fix it.

## 5. Clear any copy you already have installed

**If you use the released app, remove it before you build.** Your dev build
won't replace it — macOS has no install slot, so both copies register, both
claim the same bundle ID, and Safari ends up listing two extensions with one
identity. Worst case your edits appear to do nothing, because Safari is still
loading the signed release copy.

Quit Safari, then:

```bash
tools/uninstall-all.sh --dry-run   # see what's there
tools/uninstall-all.sh             # remove it
```

It clears every copy it can find — `/Applications`, `~/Applications`, Xcode
build products, and stale LaunchServices records. The script refuses to run
while Safari is open, on purpose. You'll reinstall the release in
[Part 3](#7-after-its-merged) once your change is merged, so nothing is lost.

Never installed it? Nothing to do — run the `--dry-run` anyway to confirm, then
carry on.

Full detail on the script, including how to get back afterwards, is in
[Part 4](#switching-between-dev-testflight-and-app-store-builds).

## 6. Make it sign, then build

macOS won't run an app that isn't signed, and the project ships with the
maintainer's signing details — which aren't yours. Two edits:

**a. Pick your team.** Click the blue **MediaKeyGuardForSafari** project at the
top of the sidebar, then in the target list select **MediaKeyGuardForSafari**
→ **Signing & Capabilities** tab → **Team** dropdown. If your Apple ID isn't
listed, choose **Add an Account…**, sign in, and come back. Pick your name
(`Your Name (Personal Team)`).

**Now do the same for the second target,** `MediaKeyGuardForSafari Extension`.
Both need it. This is the single most common way to get stuck.

**b. Give it a bundle ID that's yours.** The project's identifier
(`Life.Streamlining.MediaKeyGuardForSafari`) is registered to the maintainer's
Apple developer account, and Apple only lets one account own an identifier. As
soon as you build, Xcode tries to register it for *your* account and Apple
refuses, with some variation of *"Failed to register bundle identifier"* or
*"cannot be registered to your development team"*.

Change it to something nobody else owns, in the same **Signing &
Capabilities** tab, **Bundle Identifier** field:

| Target | Set it to |
|---|---|
| `MediaKeyGuardForSafari` | `com.YOURNAME.MediaKeyGuardForSafari` |
| `MediaKeyGuardForSafari Extension` | `com.YOURNAME.MediaKeyGuardForSafari.Extension` |

The extension's must be the app's with `.Extension` on the end.

Then edit one line of Swift to match — the wrapper app looks the extension up
by identifier, and with the old value its window can't tell whether the
extension is enabled:

[`app/MediaKeyGuardForSafari/MediaKeyGuardForSafari/ViewController.swift:12`](app/MediaKeyGuardForSafari/MediaKeyGuardForSafari/ViewController.swift)

```swift
let extensionBundleIdentifier = "com.YOURNAME.MediaKeyGuardForSafari.Extension"
```

**These three edits are yours alone and must never end up in a PR.** Leave
them sitting in your working copy uncommitted — [Part 3](#3-commit-only-what-you-changed)
covers how to commit around them.

**Build and run: ⌘R.** The scheme selector at the top should say
**MediaKeyGuardForSafari** (not *Uninstall All*). A window appears saying the
extension is off — that's the wrapper app, and its only job is to hand the
extension to Safari. Leave it.

## 7. Turn it on in Safari

The extension is now registered with Safari, but Safari won't load a build
signed by a free Apple ID until you say so:

1. **Safari → Settings → Advanced** → tick **Show features for web
   developers**. A **Develop** menu appears in the menu bar.
2. **Develop → Allow Unsigned Extensions**.
3. **Safari → Settings → Extensions** → tick **Media Key Guard for Safari**.
4. Click the extension's toolbar icon and grant site access — **Always Allow
   on Every Website** is easiest for testing, since notification sounds come
   from anywhere.

**Allow Unsigned Extensions resets every time Safari quits.** Not a bug you
can fix; only a paid Developer ID signature makes it stick. Quit Safari, re-do
step 2. You'll do this a lot.

## 8. Check it actually works

```bash
cd harness && python3 -m http.server 8642
```

Open <http://127.0.0.1:8642/> in Safari. **It must be `http://`, not a
`file://` path** — content scripts never inject into `file://` pages, so the
extension looks broken there when it's fine.

Start music playing in Spotify or Music first. The page's status bar tells you
whether the extension injected, and each test says what should happen. If a
short sound plays and your play/pause key still controls your music
afterwards, you have a working development build.

## If something went wrong

| What you see | What's happening |
|---|---|
| Red files in Xcode's sidebar, fresh clone | Expected. Build once; the sync phase creates them. |
| *"Signing for … requires a development team"* | You set the team on one target, not both. Back to [step 6a](#6-make-it-sign-then-build). |
| *"Failed to register bundle identifier"* / *"cannot be registered to your development team"* | Expected with the shipped identifier. [Step 6b](#6-make-it-sign-then-build). |
| Builds fine, no extension in Safari's Extensions list | The app has to *run* once (⌘R, not just ⌘B) to register it. Then quit and reopen Safari. |
| Extension listed but greyed out or refusing to enable | **Develop → Allow Unsigned Extensions** — and remember it resets on every Safari quit. |
| Enabled, but nothing happens on any page | No site access granted. Toolbar icon → allow on the site, or *Always Allow on Every Website*. Reload the page. |
| Two copies of the extension in Safari's list, or your edits have no effect | You have a dev build *and* a release/TestFlight build installed. Quit Safari and run `tools/uninstall-all.sh`, then ⌘R to reinstall just the dev build — [step 5](#5-clear-any-copy-you-already-have-installed). |
| Your edit to `extension/*.js` doesn't seem to apply | Rebuild (⌘R), then reload the page. If it's `background.js`, quit and reopen Safari (and re-tick Allow Unsigned Extensions). |
| Harness page says the extension didn't inject | You opened it as `file://`. Use the `http://127.0.0.1:8642/` URL. |

---

# Part 2 — Making a change

## Where things live

| Path | What |
|---|---|
| `extension/` | **The source of truth** — manifest, scripts, icons. Almost every change you'll want to make is here. |
| `app/MediaKeyGuardForSafari/` | Xcode wrapper project. Generated by `safari-web-extension-converter`, maintained by hand since. |
| `harness/` | Standalone test page that exercises every release-mechanism variant. |
| `tools/` | Icon generator, resource-sync script, install cleaner. |

Inside `extension/`:

| File | Role |
|---|---|
| `manifest.json` | Extension declaration. `version` is stamped automatically — [don't edit it](#versioning-one-file-versionxcconfig). |
| `content.js` | Runs in each page's isolated world; injects `page.js`, talks to the background. |
| `page.js` | Runs in the page's **main** world — where the media-element hooks live. Held to a stricter bar, see [PR expectations](#pr-expectations). |
| `background.js` | Service worker: settings, per-tab state, toolbar icon and badge. |
| `matcher.js` | Site-pattern matching shared by the background and options page. |
| `popup.html` / `popup.js` | Toolbar popup. |
| `options.html` / `options.js` | The site-list editor. |

## You don't need to copy anything

The Xcode project builds from **copies** of `extension/` under
`app/…/MediaKeyGuardForSafari Extension/Resources/`. Keeping them current is a
build phase — **Sync extension resources**, first phase of the extension target
— running `tools/sync-resources.sh` on every build, before resources are
copied.

So: **edit `extension/`, press ⌘R, done.** Never edit the copies; they're
overwritten and pruned on every build, and they're gitignored.

One exception: adding a **new top-level file** to `extension/` also needs it
registered in the Xcode project (drag it in, targeting the extension target,
or follow the existing entries in `project.pbxproj`). The sync copies it, but
Xcode won't bundle a file it has no reference for. New icons inside
`extension/images/` need nothing — that's a folder reference.

## The edit loop

1. Edit a file in `extension/`.
2. ⌘R in Xcode.
3. Reload the test page in Safari.

For `background.js` changes, quit and reopen Safari (then re-tick **Allow
Unsigned Extensions**) — a service worker can survive a rebuild otherwise.

To see console output, use Safari's **Develop** menu: page-world logs from
`page.js` appear in the normal Web Inspector for the page; the service
worker's own console is under **Develop → Web Extension Background Content**.

## Test it

The mechanism — releasing Safari's Now Playing claim — can't be unit-tested.
It needs real Safari making real sound. `harness/index.html` covers every
variant:

```bash
cd harness && python3 -m http.server 8642
```

`http://127.0.0.1:8642/`, music already playing in Spotify or Music, and work
through the cases. Then try a real site or two — Teams, Gmail, whatever chimes
at you. Note what you tested; the PR asks for it.

## Lint before you push

```bash
for f in extension/*.js; do node --check "$f"; done
python3 -c "import json; json.load(open('extension/manifest.json'))"
```

Silence is a pass.

---

# Part 3 — Getting it merged

The goal here is that your change lands in the project and ships in the next
release — so you can delete your build, install the released app like everyone
else, and never think about it again. That's what a merged PR buys you.

## 1. Start from an up-to-date `master`

```bash
git switch master
git pull upstream master
```

## 2. Branch

One branch per change, named for the change:

```bash
git switch -c fix-badge-on-reload
```

Make your edits and test them ([Part 2](#part-2--making-a-change)).

## 3. Commit only what you changed

Your signing edits from [step 6](#6-make-it-sign-then-build) are still sitting
in your working copy, and they must not be in the PR. So **never**
`git add -A`, `git add .`, or `git commit -a` in this repo. Name your files:

```bash
git add extension/page.js extension/background.js
git commit -m "fix: keep the badge after a reload"
```

Then check what you're about to hand over:

```bash
git status
git diff master --stat
```

`project.pbxproj` and `ViewController.swift` should appear as *modified but
unstaged* under `git status`, and should **not** appear in the `git diff
master` output. If one of them did get committed, put the original back and
amend:

```bash
git checkout upstream/master -- "app/MediaKeyGuardForSafari/MediaKeyGuardForSafari.xcodeproj/project.pbxproj"
git commit --amend --no-edit
```

(Your working copy loses the signing tweak when you do that, so re-apply it in
Xcode before your next build.)

## 4. Push to your fork

```bash
git push -u origin fix-badge-on-reload
```

## 5. Open the pull request

Visit your fork on GitHub. There's a **Compare & pull request** banner for the
branch you just pushed — click it. Check the header reads *base:
`Streamlining-Life/MediaKeyGuardForSafari` `master`* ← *compare: your fork,
your branch*.

Title it like your commit. In the body, say what it does, why, and **how you
tested it** — harness results, real sites, Safari version. Then **Create pull
request**.

## 6. Review

Expect comments. Answer them, and push fixes to the *same branch*:

```bash
git add extension/page.js
git commit -m "fix: address review"
git push
```

The PR updates itself — no new PR needed. If `master` moves under you and
GitHub reports a conflict:

```bash
git fetch upstream
git rebase upstream/master
# resolve, then
git push --force-with-lease
```

## 7. After it's merged

Done. It ships in the next release; there is no fork to keep alive and nothing
to maintain.

Tidy up — GitHub offers **Delete branch** on the merged PR, and locally:

```bash
git switch master
git pull upstream master
git branch -d fix-badge-on-reload
```

Then go back to being a normal user — same script as
[step 5](#5-clear-any-copy-you-already-have-installed), pointed the other way.
Quit Safari, then:

```bash
tools/uninstall-all.sh
```

That removes your development build, including the copies Xcode registered on
its own (a plain **Product > Build** is enough to register one, and
**Product > Archive** leaves another). Don't skip it: leave the dev copy in
place and Safari lists your build alongside the released one, both claiming
the same identity, and the media keys are handled by whichever it picked.

Now install the release: download the app from
[Releases](https://github.com/Streamlining-Life/MediaKeyGuardForSafari/releases),
move it to Applications, open it once, and re-enable the extension in **Safari
→ Settings → Extensions**. Your change is in it as soon as the next release
ships. You can also turn **Develop → Allow Unsigned Extensions** back off —
the release is properly signed and doesn't need it.

Coming back for a second change? `git pull upstream master`, new branch,
`tools/uninstall-all.sh` again to clear the release copy, and re-apply the
signing edits from [step 6](#6-make-it-sign-then-build) if you reverted them.

## PR expectations

- One concern per PR. Keep it scoped.
- `page.js` runs in every page's main world — it must never throw into the
  host page, and must not add observable globals beyond `__mediaKeyGuard`.
- Never commit signing changes, bundle identifiers, or anything under
  `app/…/MediaKeyGuardForSafari Extension/Resources/`.
- Don't bump the version — that's a release step, see
  [below](#versioning-one-file-versionxcconfig).
- Say how you tested.
- By submitting a PR you agree your contribution is licensed under the
  project's [PolyForm Noncommercial 1.0.0](LICENSE.md) license.

---

# Part 4 — Reference

Detail you don't need for a first contribution.

## Sync internals

The sync build phase needs `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the
extension target (set there, not project-wide) — the script writes to
`extension/` and to the Resources mirror, both outside the build directory.

Run it by hand only when you want the copies refreshed without a build:

```bash
tools/sync-resources.sh
```

It rsyncs with `--delete`, so a file removed from `extension/` can't linger in
the built appex.

## Versioning: one file, `Version.xcconfig`

A Safari web extension carries versions in two worlds: Apple's bundle fields
and the WebExtensions manifest. Three places would show a number, so they're
driven from one:

```
app/MediaKeyGuardForSafari/Version.xcconfig
  MARKETING_VERSION        -> app + appex CFBundleShortVersionString
                           -> extension/manifest.json "version" (stamped by
                              sync-resources.sh, which is why the popup footer
                              agrees with Safari's Extensions list)
  CURRENT_PROJECT_VERSION  -> CFBundleVersion (build number)
```

The xcconfig is assigned at **project** level, so both targets inherit it —
which matters beyond tidiness: App Store Connect rejects an upload whose appex
version differs from its containing app's.

Change the version in that one file and build. Xcode reads it for the plists;
the sync phase stamps it into `manifest.json`.

**Never type a version into a target's General tab.** That writes a
target-level override, which outranks the xcconfig and silently reintroduces
the drift.

Both fields stay numeric — App Store Connect rejects letters, and
`manifest.json` only accepts dot-separated integers, so the sync script
refuses anything else. Betas go through **TestFlight** with the version
unchanged and `CURRENT_PROJECT_VERSION` incremented per upload; "beta" never
belongs in a version string.

## Switching between dev, TestFlight and App Store builds

macOS has no install slot. An app is a folder, and LaunchServices indexes every
copy it finds rather than replacing one with the next — so a dev build does
**not** replace a TestFlight or App Store install the way it would on iOS. Both
register, both claim the same bundle ID, and Safari ends up listing two
extensions with one identity.

Xcode makes this easy to hit. A plain **Product > Build** is enough to register
the DerivedData copy — Apple documents that as intended, no Run required — and
**Product > Archive** leaves a second copy under `ArchiveIntermediates`.

Apple documents no cleanup step for any of this, so there's one here. Run it
before switching channels, then install the build you actually want to test:

```bash
tools/uninstall-all.sh
```

It finds every copy — Xcode build products, `/Applications`, `~/Applications`,
stray copies Spotlight knows about, and stale LaunchServices records pointing at
bundles that have already moved — then unregisters the lot.

- Everything found is deleted outright. Build products are regenerable and a
  TestFlight or App Store copy is a re-download away, so nothing is worth
  keeping. `--trash` moves them to the Trash instead
- `.xcarchive` contents are the exception and are kept — they hold the dSYMs
  that symbolicate crash reports from shipped builds. `--include-archives`
  overrides that
- Safari must be quit first; the script refuses to run otherwise, since
  unregistering underneath a running Safari leaves the old entry on screen.
  `--force` overrides

`--dry-run` lists what would go without touching anything, and works with Safari
open. `-y` skips the confirmation prompt.

### Running it from Xcode

There's an **Uninstall All** aggregate target for this. Pick it in the scheme
selector and hit ⌘B — the whole job is one Run Script phase, so a "build" of
that target is just the script.

Three things about that target, if you're editing it:

- The phase passes `-y`, because a build phase has no stdin and the
  confirmation prompt would hang the build waiting for an answer nobody can give
- It sets `ENABLE_USER_SCRIPT_SANDBOXING = NO` for the same reason the extension
  target does — the script works outside the build directory
- Run from the terminal, the script clears the project's whole DerivedData tree,
  which is the surest way to drop stale build hashes. Run from this target it
  removes only the built app bundles and leaves the tree alone: that tree holds
  the build database the running build is using, and deleting it mid-build ends
  in `accessing build database ...: disk I/O error`

**If Safari is open the build fails on purpose** — the script won't unregister
extensions out from under a running Safari. The reason appears in the issue
navigator as a normal build error, because the script prefixes it `error:` when
`XCODE_VERSION_ACTUAL` is set; without that prefix Xcode swallows script output
into the log and you get an unexplained red banner.

The scheme is autocreated by Xcode rather than committed, matching every other
scheme in this project — `xcuserdata/` is gitignored, so nothing to check in.

Going back to dev afterwards needs nothing extra — build in Xcode and the dev
copy registers itself again.
