#!/bin/zsh
# Builds "build/Quota Float.app" and a release zip "build/QuotaFloat-<version>.zip".
#
#   scripts/build.sh                     universal (arm64 + x86_64) build, ad-hoc signed
#   ARCHS=arm64 scripts/build.sh         native-only build (faster)
#   SIGN_IDENTITY="Developer ID Application: …" scripts/build.sh
#                                        sign with a Developer ID and the hardened runtime
#   NOTARY_PROFILE=<profile> …           also notarize (xcrun notarytool keychain profile) and staple
set -eu
cd "${0:A:h}/.."
VERSION=$(<VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
ARCHS=(${=ARCHS:-arm64 x86_64})
OUT="$PWD/build"
STAGE=$(mktemp -d /private/tmp/quota-float-build.XXXXXX)
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Quota Float.app"
ZIP="QuotaFloat-$VERSION.zip"

binaries=()
for arch in $ARCHS; do
  args=(-c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/$arch")
  swift build $args
  binaries+=("$(swift build $args --show-bin-path)/QuotaFloat")
done

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create $binaries -output "$APP/Contents/MacOS/QuotaFloat"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Support/Info.plist > "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/"

# Signing happens in /private/tmp because synced folders can add extended attributes that codesign rejects.
xattr -cr "$APP"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"

(cd "$STAGE" && ditto -c -k --keepParent "Quota Float.app" "$ZIP")
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$STAGE/$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm "$STAGE/$ZIP"
  (cd "$STAGE" && ditto -c -k --keepParent "Quota Float.app" "$ZIP")
fi

mkdir -p "$OUT"
rm -rf "$OUT/Quota Float.app" "$OUT/$ZIP"
ditto --norsrc --noextattr "$APP" "$OUT/Quota Float.app"
cp "$STAGE/$ZIP" "$OUT/$ZIP"
echo "Built $OUT/Quota Float.app ($VERSION, build $BUILD, $(lipo -archs "$OUT/Quota Float.app/Contents/MacOS/QuotaFloat"))"
(cd "$OUT" && shasum -a 256 "$ZIP")
