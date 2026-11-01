#!/bin/zsh
# Builds MultiCoding.app into ./build.
#   ./build.sh            builds and installs /Applications/MultiCoding.app, signed for development.
#   ./build.sh --beta     builds and installs "MultiCoding Beta" instead: a separate app with its own
#                         preferences and workspace, so you can try a branch next to the release build.
#   ./build.sh --dist     builds a distributable release: signed with the Developer ID certificate,
#                         hardened runtime, notarized and stapled; produces build/MultiCoding-<version>.dmg
#                         and build/MultiCoding-<version>.zip. Doesn't install anything.
#                         Needs a notarytool keychain profile (see NOTARY_PROFILE below).
#   ./build.sh --dist --no-notarize   same, but skips notarization (for checking the build).
set -e
# A failure anywhere in a pipeline counts; otherwise a failed swift build goes on to package
# and install the previous binary.
setopt pipe_fail
setopt null_glob
cd "$(dirname "$0")"

NAME=MultiCoding
BUNDLE_ID=com.emreaykutalp.multicoding
MODE=install
NOTARIZE=1
NOTARY_PROFILE=${NOTARY_PROFILE:-multicoding-notary}
for arg in "$@"; do
  case "$arg" in
    --beta) NAME="MultiCoding Beta"; BUNDLE_ID=com.emreaykutalp.multicoding.beta ;;
    --dist) MODE=dist ;;
    --no-notarize) NOTARIZE=0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

swift build -c release 2>&1 | grep -E "error|warning: unre|Compiling|Build complete" | tail -20

APP="build/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MultiCoding "$APP/Contents/MacOS/MultiCoding"
cp Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Set :CFBundleName $NAME" -c "Set :CFBundleDisplayName $NAME" \
  -c "Set :NSServices:0:NSMenuItem:default Open in $NAME" -c "Set :NSServices:0:NSPortName $NAME" "$APP/Contents/Info.plist"
cp Resources/MultiCoding.icns "$APP/Contents/Resources/"
for icon in Resources/claude.svg Resources/codex.svg Resources/antigravity.svg; do
  [ -e "$icon" ] && cp "$icon" "$APP/Contents/Resources/"
done
if [ -e Resources/antigravity-statusline.sh ]; then
  cp Resources/antigravity-statusline.sh "$APP/Contents/Resources/"
  chmod +x "$APP/Contents/Resources/antigravity-statusline.sh"
fi
for bundle in .build/release/*.bundle; do
  [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done
# Filters a command's output like grep -v, without failing when nothing is left to print.
without() { grep -v "$@" || true; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

if [[ "$MODE" == "install" ]]; then
  # A stable signing identity keeps macOS from re-asking permissions after each rebuild.
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | awk '{print $2}' || true)
  codesign --force --sign "${IDENTITY:--}" "$APP" 2>&1 | without "replacing existing signature"
  # Install to /Applications so Finder's "Open in MultiCoding" service and Dock stay registered.
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" "/Applications/$NAME.app"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$NAME.app"
  /System/Library/CoreServices/pbs -flush 2>/dev/null || true
  /System/Library/CoreServices/pbs -update 2>/dev/null || true
  echo "Built and installed /Applications/$NAME.app ($(du -sh "$APP" | cut -f1))"
  exit 0
fi

# --- Distribution build ---
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
if [[ -z "$IDENTITY" ]]; then
  if [[ "$NOTARIZE" == 1 ]]; then
    echo "No 'Developer ID Application' certificate in the keychain. Create one in Xcode › Settings › Accounts › Manage Certificates, or pass --no-notarize for an ad-hoc signed local build." >&2
    exit 1
  fi
  IDENTITY="-"
  echo "No Developer ID certificate found; packaging an ad-hoc signed build (macOS may require manual approval to open it)." >&2
fi
if [[ "$NOTARIZE" == 1 ]] && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<MSG
No notarytool credentials stored as '$NOTARY_PROFILE'. Store them once (asks for an app-specific
password from account.apple.com › Sign-In and Security › App-Specific Passwords):

  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <your Apple ID> --team-id <your Team ID>

Or run with --no-notarize to only sign.
MSG
  exit 1
fi

# Hardened runtime and a secure timestamp are required for notarization.
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"

ARTIFACT="build/${NAME// /-}-$VERSION"
ZIP="$ARTIFACT.zip"
DMG="$ARTIFACT.dmg"
rm -f "$ZIP" "$DMG"

notarize() {
  echo "Notarizing $1…"
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | grep -E "status:|id:" | tail -2
}

if [[ "$NOTARIZE" == 1 ]]; then
  ditto -c -k --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  xcrun stapler staple "$APP" >/dev/null
  rm -f "$ZIP"
fi
# The zip carries the stapled app, so it works offline too.
ditto -c -k --keepParent "$APP" "$ZIP"

# DMG: the app next to an Applications shortcut, so users drag one onto the other.
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGE"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$DMG"
else
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi
if [[ "$NOTARIZE" == 1 ]]; then
  notarize "$DMG"
  xcrun stapler staple "$DMG" >/dev/null
fi

echo "Built $DMG ($(du -h "$DMG" | cut -f1)) and $ZIP ($(du -h "$ZIP" | cut -f1))"
[[ "$NOTARIZE" == 1 ]] && spctl --assess --type open --context context:primary-signature -v "$DMG" 2>&1 | tail -1 || true
