#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'This build requires macOS and Xcode.' >&2; exit 1; }
mkdir -p build
workspace="$(python3 -c 'from pathlib import Path; print(next(iter(Path("ios").glob("*.xcworkspace")), ""))')"
[[ -n "$workspace" ]] || { echo 'Run expo prebuild and pod install first.' >&2; exit 1; }
scheme="$(basename "$workspace" .xcworkspace)"
xcodebuild -workspace "$workspace" -list -json > build/xcode-schemes.json
python3 - "$scheme" <<'PY'
import json, sys
p=json.load(open('build/xcode-schemes.json'))
assert sys.argv[1] in p['workspace']['schemes'], 'Application scheme was not found'
PY
xcodebuild -workspace "$workspace" -scheme "$scheme" \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/build/ios" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' \
  build 2>&1 | tee build/xcodebuild.log
app="$(python3 -c 'from pathlib import Path; print(next(iter(Path("build/ios/Build/Products/Release-iphoneos").glob("*.app")), ""))')"
[[ -n "$app" ]] || { echo 'Application bundle was not produced.' >&2; exit 1; }
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")" == 'com.manhwastudio.app' ]]
executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Info.plist")"
lipo -archs "$app/$executable" | grep -qw arm64
rm -rf build/package
mkdir -p build/package/Payload
ditto "$app" "build/package/Payload/$(basename "$app")"
package_app="build/package/Payload/$(basename "$app")"
# Some prebuilt dependency frameworks may arrive ad-hoc signed. Remove their
# signatures too, so the resulting IPA can be signed with the user's own tools.
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    chmod u+w "$binary"
    codesign --remove-signature "$binary" >/dev/null 2>&1 || true
    if codesign --display "$binary" >/dev/null 2>&1; then
      echo "Unexpected signature remains: $binary" >&2; exit 1
    fi
  fi
done < <(find "$package_app" -type f -print0)
find "$package_app" -type d -name _CodeSignature -prune -exec rm -rf '{}' +
find "$package_app" -name embedded.mobileprovision -delete
(cd build/package && ditto -c -k --keepParent Payload ../manhwa-studio-unsigned.ipa)
python3 - <<'PY'
import zipfile
with zipfile.ZipFile('build/manhwa-studio-unsigned.ipa') as z:
    assert z.testzip() is None
    assert any(n.startswith('Payload/') and n.endswith('.app/Info.plist') for n in z.namelist())
    assert not any('/_CodeSignature/' in n or n.endswith('embedded.mobileprovision') for n in z.namelist())
print('Unsigned device IPA packaged and verified.')
PY
shasum -a 256 build/manhwa-studio-unsigned.ipa > build/manhwa-studio-unsigned.ipa.sha256
