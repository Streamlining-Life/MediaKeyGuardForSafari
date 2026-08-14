#!/bin/sh
# Render the App Store screenshot canvases in tools/ to shots/*.png.
#
# Each canvas lays out at 1440x900 CSS px and is rendered at a 2x device scale
# factor, so the PNG lands on 2880x1800 — an App Store macOS screenshot size —
# with every glyph drawn at that resolution. A capture of the real UI cannot
# match it: macOS renders at 2x and never more, so the popup is only ~570px
# wide however it is grabbed, and filling the slot from that means upscaling.
#
# The canvases carry the extension's own markup and CSS plus rebuilt Safari
# furniture. Anything that could drift from the shipped release is stamped in
# here rather than typed into the canvas: the version from Version.xcconfig,
# the site-list tab title from options.html. The icons are referenced straight
# out of extension/images/.
#
# Chrome does the rendering because it is the only headless engine on macOS.
# Re-run after any UI change — or use the "Make Screenshots" scheme in Xcode.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/shots"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -x "$CHROME" ] || { echo "Google Chrome not found at $CHROME" >&2; exit 1; }

# Same single source of truth the appex and manifest.json versions come from.
VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*//p' \
  "$ROOT/app/MediaKeyGuardForSafari/Version.xcconfig" | tr -d '[:space:]')"
[ -n "$VERSION" ] || { echo "no MARKETING_VERSION in Version.xcconfig" >&2; exit 1; }

# The window title in the site-list shot is the page's real <title>, so
# renaming the page renames it in the screenshot too.
OPTIONS_TITLE="$(sed -n 's|.*<title>\(.*\)</title>.*|\1|p' "$ROOT/extension/options.html" | head -1)"
[ -n "$OPTIONS_TITLE" ] || { echo "no <title> in extension/options.html" >&2; exit 1; }

# & and \ are replacement metacharacters to sed; | is the delimiter below.
escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

mkdir -p "$OUT"

for canvas in "$ROOT"/tools/shotcanvas-*.html; do
  [ -f "$canvas" ] || { echo "no shotcanvas-*.html in $ROOT/tools" >&2; exit 1; }

  name="$(basename "$canvas" .html)"
  name="${name#shotcanvas-}"

  # Both appearances: the extension follows the system one, and showing that
  # on the listing costs nothing — App Store Connect takes ten screenshots.
  for theme in light dark; do
    png="$OUT/$name-$theme-2880x1800.png"

    # Stamped copy lives beside the canvas so its relative paths to
    # extension/images/ and shotcanvas.css still resolve.
    stamped="$ROOT/tools/.shot-$name-$theme.html"
    trap 'rm -f "$stamped"' EXIT INT TERM
    sed -e "s|{{VERSION}}|$(escape "$VERSION")|g" \
        -e "s|{{OPTIONS_TITLE}}|$(escape "$OPTIONS_TITLE")|g" \
        -e "s|{{THEME}}|$theme|g" \
        "$canvas" > "$stamped"

    # No --disable-gpu: without a raster path backdrop-filter silently no-ops
    # and every glass surface comes out flat. SwiftShader handles it headless.
    "$CHROME" \
      --headless=new \
      --hide-scrollbars \
      --allow-file-access-from-files \
      --force-device-scale-factor=2 \
      --window-size=1440,900 \
      --virtual-time-budget=3000 \
      --screenshot="$png" \
      "file://$stamped" >/dev/null 2>&1

    rm -f "$stamped"

    [ -f "$png" ] || { echo "Chrome produced no screenshot for $name/$theme" >&2; exit 1; }

    # App Store Connect rejects anything off-size, so fail here not there.
    size="$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel/ {print $2}' | paste -sd x -)"
    [ "$size" = "2880x1800" ] || { echo "$png is ${size}, expected 2880x1800" >&2; exit 1; }

    echo "${png#$ROOT/}  $size  (v$VERSION)"
  done
done
