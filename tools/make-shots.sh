#!/bin/sh
# Render the App Store screenshot canvases in tools/ to shots/*.png,
# using REAL SAFARI as the renderer.
#
# Why Safari: the canvases contain the extension's own popup/options markup,
# and only WebKit draws its form controls — buttons, the number stepper, the
# focus ring — the way they look in the real extension. A headless engine
# (Chrome) substitutes its own controls and every one of them reads wrong.
#
# How: via safaridriver (Safari's WebDriver). Safari screenshots its own
# viewport, so no Screen Recording or Apple-events permission is involved —
# which also makes this runnable from an Xcode build phase, whose build
# service never inherits Xcode's TCC grants. One-time setup instead:
#
#   Safari > Settings > Advanced > "Show features for web developers",
#   then Develop > "Allow Remote Automation"   (or: safaridriver --enable)
#
# The display runs at 1x, so device px == CSS px and the viewport screenshot
# comes back pixel-for-pixel. Each canvas lays out a 2880x1800 .frame under a
# 3px magenta sentinel strip; the crop takes the 2880x1800 directly below the
# sentinel, so exact viewport metrics never matter.
#
# Anything that could drift from the shipped release is stamped in here
# rather than typed into the canvas: the version from Version.xcconfig, the
# site-list tab title from options.html. The icons are referenced straight
# out of extension/images/.
#
# Re-run after any UI change — or use the "Make Screenshots" scheme in Xcode
# (output lands in the build log: Report navigator, latest Build, expand the
# "Render the App Store screenshots" phase). VERBOSE=1 traces every command.
# On a failed crop the raw viewport capture is kept in shots/ for inspection.
set -eu
[ "${VERBOSE:-0}" = "1" ] && set -x

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/shots"

# Same single source of truth the appex and manifest.json versions come from.
VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*//p' \
  "$ROOT/app/MediaKeyGuardForSafari/Version.xcconfig" | tr -d '[:space:]')"
[ -n "$VERSION" ] || { echo "no MARKETING_VERSION in Version.xcconfig" >&2; exit 1; }

# The window title in the site-list shot is the page's real <title>, so
# renaming the page renames it in the screenshot too.
OPTIONS_TITLE="$(sed -n 's|.*<title>\(.*\)</title>.*|\1|p' "$ROOT/extension/options.html" | head -1)"
[ -n "$OPTIONS_TITLE" ] || { echo "no <title> in extension/options.html" >&2; exit 1; }

python3 -c 'import PIL' 2>/dev/null \
  || { echo "needs Pillow for the sentinel crop: python3 -m pip install Pillow" >&2; exit 1; }

# & and \ are replacement metacharacters to sed; | is the delimiter below.
escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

mkdir -p "$OUT"
trap 'rm -f "$ROOT"/tools/.shot-*.html' EXIT INT TERM

# Stamp every canvas in both appearances. The canvas forces its colour scheme
# from the data-theme stamp, so the system's appearance doesn't matter. Both
# themes cost nothing on the listing — App Store Connect takes ten shots.
PAIRS=""
for canvas in "$ROOT"/tools/shotcanvas-*.html; do
  [ -f "$canvas" ] || { echo "no shotcanvas-*.html in $ROOT/tools" >&2; exit 1; }
  name="$(basename "$canvas" .html)"
  name="${name#shotcanvas-}"
  for theme in light dark; do
    stamped="$ROOT/tools/.shot-$name-$theme.html"
    sed -e "s|{{VERSION}}|$(escape "$VERSION")|g" \
        -e "s|{{OPTIONS_TITLE}}|$(escape "$OPTIONS_TITLE")|g" \
        -e "s|{{THEME}}|$theme|g" \
        "$canvas" > "$stamped"
    PAIRS="$PAIRS $stamped|$OUT/$name-$theme-2880x1800.png"
  done
done

# One Safari session captures the lot.
python3 - $PAIRS <<'PYTHON'
import base64, io, json, socket, subprocess, sys, time, urllib.request
from pathlib import Path
from PIL import Image

PORT = 4899
pairs = [a.split("|", 1) for a in sys.argv[1:]]

driver = subprocess.Popen(["safaridriver", "-p", str(PORT)],
                          stderr=subprocess.PIPE, stdout=subprocess.DEVNULL)

def wait_for_port():
    for _ in range(50):
        if driver.poll() is not None:
            err = driver.stderr.read().decode(errors="replace").strip()
            sys.exit("safaridriver would not start%s\n"
                     "Enable Safari > Develop > Allow Remote Automation "
                     "(Develop menu on via Settings > Advanced), or run: "
                     "safaridriver --enable" % (f": {err}" if err else ""))
        try:
            socket.create_connection(("127.0.0.1", PORT), 0.2).close()
            return
        except OSError:
            time.sleep(0.2)
    sys.exit("safaridriver did not open its port")

def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}",
                               data=data, method=method,
                               headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return json.load(resp)["value"]
    except urllib.error.HTTPError as e:
        try:
            detail = json.load(e)["value"]["message"]
        except Exception:
            detail = e.read().decode(errors="replace")
        sys.exit(f"safaridriver refused {method} {path}: {detail}\n"
                 "If this mentions Remote Automation: enable Safari > Develop "
                 "> Allow Remote Automation (Develop menu on via Settings > "
                 "Advanced), or run: safaridriver --enable")

wait_for_port()
try:
    session = req("POST", "/session", {"capabilities": {"alwaysMatch": {}}})
    sid = session["sessionId"]
    s = f"/session/{sid}"
    # Wide enough for the 2880 frame, tall enough that the viewport holds
    # sentinel (3px) + frame (1800px) under whatever chrome Safari keeps.
    req("POST", f"{s}/window/rect", {"x": 0, "y": 0, "width": 2896, "height": 2010})

    for stamped, out in pairs:
        label = Path(out).stem.replace("-2880x1800", "")
        print(f">> [{label}] rendering in Safari", flush=True)
        req("POST", f"{s}/url", {"url": Path(stamped).absolute().as_uri()})
        time.sleep(1.2)  # let fonts, gradients and backdrop blurs settle
        shot = base64.b64decode(req("GET", f"{s}/screenshot"))
        im = Image.open(io.BytesIO(shot)).convert("RGB")
        w, h = im.size
        px = im.load()

        def magenta(p):
            r, g, b = p
            return r > 200 and g < 90 and b > 200

        rows = [y for y in range(min(h, 60))
                if magenta(px[w // 2, y]) and magenta(px[60, y])]
        if not rows or w < 2880 or h - (rows[-1] + 1) < 1800:
            keep = Path(out).with_name(f"failed-{Path(out).name}")
            im.save(keep)
            sys.exit(f"no usable sentinel/frame in the capture ({w}x{h}) - "
                     f"raw viewport kept at {keep}")
        top = rows[-1] + 1
        im.crop((0, top, 2880, top + 1800)).save(out)
        print(f"{out}  2880x1800", flush=True)

    req("DELETE", s)
finally:
    driver.terminate()
PYTHON

echo "done (v$VERSION)"
