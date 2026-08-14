#!/bin/sh
# Sync the extension source of truth (extension/) into the Xcode project's
# copied resources, stamping the version from Version.xcconfig on the way.
# The converter copied resources rather than referencing them, so every
# extension edit must be mirrored before building — run this instead of
# hand-copying. Fails loudly on any copy error.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/extension"
DEST="$ROOT/app/MediaKeyGuardForSafari/MediaKeyGuardForSafari Extension/Resources"
XCCONFIG="$ROOT/app/MediaKeyGuardForSafari/Version.xcconfig"

[ -d "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }
[ -f "$XCCONFIG" ] || { echo "missing $XCCONFIG" >&2; exit 1; }

# DEST is a gitignored build artifact — absent on a fresh clone, so create it
# rather than treating absence as an error.
mkdir -p "$DEST"

# Version.xcconfig is the one place versions are set; manifest.json must
# carry a version of its own, kept in step here.
# Stamp SRC (not just DEST) so the committed source stays honest and the bump
# shows up in the diff — the rsync below then carries it into the appex.
VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*//p' "$XCCONFIG" | tr -d '[:space:]')"
case "$VERSION" in
  '' ) echo "no MARKETING_VERSION in $XCCONFIG" >&2; exit 1 ;;
  # manifest.json accepts 1-4 dot-separated integers and nothing else.
  *[!0-9.]* ) echo "MARKETING_VERSION '$VERSION' is not numeric — manifest.json will not load" >&2; exit 1 ;;
esac

sed -i '' -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*\"/\1${VERSION}\"/" "$SRC/manifest.json"
grep -q "\"version\": \"$VERSION\"" "$SRC/manifest.json" \
  || { echo "failed to stamp $VERSION into extension/manifest.json" >&2; exit 1; }

# --delete keeps DEST an exact mirror so removed extension files can't linger
# in the built appex.
rsync -a --delete "$SRC/" "$DEST/"
echo "synced extension/ -> ${DEST#$ROOT/} (version $VERSION)"
