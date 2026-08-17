#!/bin/sh
# Stamp MARKETING_VERSION from Version.xcconfig into the extension's
# manifest.json, so the app bundle and the WebExtensions manifest can never
# report different versions. Runs as the extension target's first build phase,
# before the resources are copied into the appex.
#
# Writes to the tracked source file on purpose: the bump then shows up in the
# git diff instead of happening invisibly inside build output.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/app/MediaKeyGuardForSafari/MediaKeyGuardForSafari Extension/Resources/manifest.json"
XCCONFIG="$ROOT/app/MediaKeyGuardForSafari/Version.xcconfig"

[ -f "$MANIFEST" ] || { echo "missing $MANIFEST" >&2; exit 1; }
[ -f "$XCCONFIG" ] || { echo "missing $XCCONFIG" >&2; exit 1; }

VERSION="$(sed -n 's/^[[:space:]]*MARKETING_VERSION[[:space:]]*=[[:space:]]*//p' "$XCCONFIG" | tr -d '[:space:]')"
case "$VERSION" in
  '' ) echo "no MARKETING_VERSION in $XCCONFIG" >&2; exit 1 ;;
  # manifest.json accepts 1-4 dot-separated integers and nothing else.
  *[!0-9.]* ) echo "MARKETING_VERSION '$VERSION' is not numeric — manifest.json will not load" >&2; exit 1 ;;
esac

sed -i '' -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*\"/\1${VERSION}\"/" "$MANIFEST"
grep -q "\"version\": \"$VERSION\"" "$MANIFEST" \
  || { echo "failed to stamp $VERSION into ${MANIFEST#$ROOT/}" >&2; exit 1; }

echo "stamped version $VERSION into ${MANIFEST#$ROOT/}"
