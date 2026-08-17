#!/bin/sh
# Remove every installed copy of the app and its Safari extension, wherever it
# came from — Xcode build, TestFlight, App Store, a stray copy in Downloads.
#
# TestFlight and App Store copies are the one thing this script cannot delete
# for you: they are installed as root, so an unprivileged rm -rf fails partway
# into the bundle. Those are detected up front and the run refuses to start
# until you have moved them to the Trash in Finder yourself. So a run that
# finishes has removed everything.
#
# macOS has no install slot. An app is a folder, and LaunchServices indexes
# every copy it finds rather than replacing one with the next, so two copies
# sharing a bundle ID both register and Safari ends up with two extensions
# claiming one identity. Xcode makes this easy to hit: a plain Product > Build
# is enough to register the DerivedData copy, and Product > Archive leaves a
# second one under ArchiveIntermediates.
#
# Run this before switching channels (dev <-> TestFlight <-> App Store) so
# exactly one copy is ever installed, then install the one you want to test.
#
# Every copy it removes is deleted outright: build products are regenerable and
# a released copy is a re-download away, so there is nothing worth leaving in
# the Trash. Pass --trash if you want them kept there anyway.
# Archives are the one exception and are left alone unless asked for: they carry
# the dSYMs needed to symbolicate crash reports from shipped builds.
set -eu

APP_ID="Life.Streamlining.MediaKeyGuardForSafari"
EXT_ID="$APP_ID.Extension"
PROJECT="MediaKeyGuardForSafari"
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"

DRY=0
ASSUME_YES=0
WITH_ARCHIVES=0
USE_TRASH=0
FORCE=0

usage() {
	cat <<EOF
usage: ${0##*/} [-n] [-y] [--trash] [--force] [--include-archives]

  -n, --dry-run          list what would be removed, change nothing
  -y, --yes              skip the confirmation prompt
      --trash            move copies to the Trash instead of deleting them
      --force            run even with Safari open
      --include-archives also remove copies inside .xcarchive bundles
                         (destroys the dSYMs for those builds)
EOF
}

# Xcode only surfaces a build script's output in the issue navigator when the
# line is prefixed error: or warning: — without that, a failure here is just a
# red "Build failed" with the reason buried in the log. Outside a build phase
# the prefix is noise, so pick per context: XCODE_VERSION_ACTUAL is set by the
# build system and nothing else.
die() {
	if [ -n "${XCODE_VERSION_ACTUAL:-}" ]; then
		echo "error: $1"
	else
		echo "$1" >&2
	fi
	exit "${2:-1}"
}

for arg in "$@"; do
	case "$arg" in
		-n|--dry-run) DRY=1 ;;
		-y|--yes) ASSUME_YES=1 ;;
		--trash) USE_TRASH=1 ;;
		--force) FORCE=1 ;;
		--include-archives) WITH_ARCHIVES=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown option: $arg" >&2; usage >&2; exit 2 ;;
	esac
done

[ -x "$LSREG" ] || die "lsregister not found at $LSREG"

# Safari holds its extension list open; unregistering underneath it leaves the
# old entry on screen and invites exactly the confusion this script prevents.
# Discovery is read-only, so a dry run is fine with Safari up.
if [ "$DRY" -eq 0 ] && [ "$FORCE" -eq 0 ] && pgrep -x Safari >/dev/null 2>&1; then
	die "Safari is running — quit it (Cmd-Q), then try again. Pass --force to override."
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- discovery -------------------------------------------------------------
# Four sources, unioned. No single one sees everything: pluginkit only knows
# what Safari can currently load, LaunchServices keeps records after a bundle
# moves, Spotlight finds unregistered copies, and a direct check covers the
# standard locations when indexing is stale or switched off.

FOUND="$WORK/found"
: > "$FOUND"

# Apple's documented view of what Safari sees (see Troubleshooting your Safari
# web extension). Parent Bundle is the containing .app, not the .appex.
pluginkit -mAvvv -i "$EXT_ID" 2>/dev/null \
	| sed -n 's/^[[:space:]]*Parent Bundle = //p' >> "$FOUND" || true

# Catches stale registrations whose bundle has already moved or been deleted.
# The trailing " (0x...)" is the LaunchServices record id, not part of the path.
"$LSREG" -dump 2>/dev/null \
	| sed -n 's/^[[:space:]]*path:[[:space:]]*//p' \
	| sed 's/ (0x[0-9a-f]*)$//' \
	| grep "/$PROJECT\.app\$" >> "$FOUND" || true

# Copies nobody registered — a zip expanded in Downloads, a copy on the Desktop.
mdfind "kMDItemCFBundleIdentifier == '$APP_ID'" 2>/dev/null >> "$FOUND" || true

for dir in /Applications "$HOME/Applications"; do
	if [ -d "$dir/$PROJECT.app" ]; then
		echo "$dir/$PROJECT.app" >> "$FOUND"
	fi
done

# --- plan ------------------------------------------------------------------
# Classify before touching anything, so the confirmation prompt describes the
# real actions rather than a guess.

PLAN="$WORK/plan"
: > "$PLAN"

sort -u "$FOUND" | grep . > "$WORK/paths" || true

while IFS= read -r app; do
	[ -n "$app" ] || continue
	# Spotlight and LaunchServices both hand back paths whose bundle has already
	# gone — a stale index entry, or a record left behind by a deleted build.
	# Nothing to remove, but the record still needs dropping.
	if [ ! -e "$app" ]; then
		printf 'unregister\t%s\n' "$app" >> "$PLAN"
		continue
	fi
	case "$app" in
		*.xcarchive/*)
			if [ "$WITH_ARCHIVES" -eq 1 ]; then
				printf 'remove\t%s\n' "$app" >> "$PLAN"
			else
				printf 'keep\t%s\n' "$app" >> "$PLAN"
			fi
			;;
		# Already in the Trash: the copy is gone as far as the user is
		# concerned, but its LaunchServices record can still be live.
		"$HOME"/.Trash/*) printf 'unregister\t%s\n' "$app" >> "$PLAN" ;;
		"$DERIVED"/*) printf 'build\t%s\n' "$app" >> "$PLAN" ;;
		*) printf 'remove\t%s\n' "$app" >> "$PLAN" ;;
	esac
done < "$WORK/paths"

# A copy installed by TestFlight or the App Store is owned by root. /Applications
# is group-writable, so the unlink can look permitted right up until rm -rf
# recurses into root-owned contents and stops — leaving a half-deleted bundle,
# which is worse than not starting. Nothing unprivileged can remove these, and
# escalating is not an option: the rest of this script writes to $HOME, so
# running it under sudo would leave root-owned droppings there. Find them before
# anything is touched and refuse the whole run instead.
BLOCKED="$WORK/blocked"
: > "$BLOCKED"
while IFS="$(printf '\t')" read -r kind path; do
	case "$kind" in
		remove|build) ;;
		*) continue ;;
	esac
	[ -e "$path" ] || continue
	if [ "$(stat -f %u "$path" 2>/dev/null)" != "$(id -u)" ]; then
		printf '%s\n' "$path" >> "$BLOCKED"
	fi
done < "$PLAN"

# Clearing the whole DerivedData tree is the surest way to drop old build hashes
# — but never from inside a build phase. That tree holds the build database the
# running build is using, and pulling it out mid-build kills the build with
# "accessing build database ...: disk I/O error". Under Xcode the individual app
# bundles removed above are enough: everything else down there is intermediates
# and index data, not copies Safari can see.
DERIVED_DIRS=""
if [ -z "${XCODE_VERSION_ACTUAL:-}" ]; then
	for d in "$DERIVED/$PROJECT"-*; do
		if [ -d "$d" ]; then
			DERIVED_DIRS="$DERIVED_DIRS$d
"
		fi
	done
fi

if [ ! -s "$PLAN" ] && [ -z "$DERIVED_DIRS" ]; then
	echo "nothing installed — no copies of $APP_ID found"
	exit 0
fi

echo "found:"
while IFS="$(printf '\t')" read -r kind path; do
	case "$kind" in
		remove)
			if grep -Fxq "$path" "$BLOCKED"; then
				echo "  MOVE BY HAND    $path"
			elif [ "$USE_TRASH" -eq 1 ]; then
				echo "  move to Trash   $path"
			else
				echo "  delete          $path"
			fi
			;;
		build)      echo "  delete (build)  $path" ;;
		unregister) echo "  unregister only $path" ;;
		keep)       echo "  KEEP (archive)  $path" ;;
	esac
done < "$PLAN"

if [ -n "$DERIVED_DIRS" ]; then
	printf '%s' "$DERIVED_DIRS" | while IFS= read -r d; do
		[ -n "$d" ] && echo "  delete (build)  $d"
	done
elif [ -n "${XCODE_VERSION_ACTUAL:-}" ] && [ -d "$DERIVED" ]; then
	echo "  (DerivedData tree kept — this build is using it)"
fi

if [ "$DRY" -eq 1 ]; then
	echo
	echo "dry run — nothing changed"
	exit 0
fi

# Same shape as the Safari check: stop before anything is removed, so the run is
# all-or-nothing. No --force here — force lets you proceed with Safari open,
# but nothing lets this proceed, and a partial uninstall is the exact mess this
# script exists to prevent.
if [ -s "$BLOCKED" ]; then
	echo >&2
	echo "these copies are owned by root and cannot be removed by this script:" >&2
	sed 's/^/  /' "$BLOCKED" >&2
	# Put the first one on screen so the drag to the Trash is one gesture away.
	# Never from inside a build phase: Finder taking focus mid-build is not
	# something a build should do.
	if [ -z "${XCODE_VERSION_ACTUAL:-}" ]; then
		open -R "$(head -1 "$BLOCKED")" 2>/dev/null || true
	fi
	die "move them to the Trash in Finder, then run this again"
fi

if [ "$ASSUME_YES" -eq 0 ]; then
	echo
	printf 'proceed? [y/N] '
	read -r reply
	case "$reply" in
		y|Y|yes|YES) ;;
		*) echo "aborted"; exit 1 ;;
	esac
fi

# --- removal ---------------------------------------------------------------

# Only used with --trash. ~/.Trash keeps one name per item, so a second
# MediaKeyGuardForSafari.app would clobber the first — number them the way
# Finder does.
trash_it() {
	base="${1##*/}"
	dest="$HOME/.Trash/$base"
	n=2
	while [ -e "$dest" ]; do
		dest="$HOME/.Trash/${base%.app} $n.app"
		n=$((n + 1))
	done
	mv "$1" "$dest"
	echo "  trashed         $dest"
}

echo
while IFS="$(printf '\t')" read -r kind path; do
	[ "$kind" = "keep" ] && continue
	# Unregistering the .app takes its embedded .appex with it. Paths that no
	# longer exist error with -10814; harmless, the record is dropped anyway.
	"$LSREG" -u "$path" >/dev/null 2>&1 || true
	case "$kind" in
		remove)
			if [ ! -e "$path" ]; then
				echo "  gone            $path"
			elif [ "$USE_TRASH" -eq 1 ]; then
				trash_it "$path"
			else
				rm -rf "$path"
				echo "  deleted         $path"
			fi
			;;
		build)
			rm -rf "$path"
			echo "  deleted         $path"
			;;
		unregister) echo "  unregistered    $path" ;;
	esac
done < "$PLAN"

if [ -n "$DERIVED_DIRS" ]; then
	rm -rf "$DERIVED/$PROJECT"-*
	echo "  deleted         $DERIVED/$PROJECT-*"
fi

# Drops records whose paths no longer exist — old DerivedData hashes, and the
# ArchiveIntermediates copy that Product > Archive leaves behind.
"$LSREG" -gc

# --- verify ----------------------------------------------------------------

echo
echo "visible to Safari now:"
if pluginkit -mAvvv -p com.apple.Safari.web-extension 2>/dev/null | grep -i "$APP_ID"; then
	echo
	die "a copy survived — its bundle is somewhere the sweep above didn't cover"
fi
echo "  none"
