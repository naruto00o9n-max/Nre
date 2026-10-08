#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
app='app/build/ios/iphoneos/Runner.app'
[[ -d "$app" ]]
mkdir -p build
rm -rf build/package
mkdir -p build/package/Payload
ditto "$app" build/package/Payload/Runner.app
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    chmod u+w "$binary"
    codesign --remove-signature "$binary" >/dev/null 2>&1 || true
    if codesign --display "$binary" >/dev/null 2>&1; then
      echo 'A binary signature remains.' >&2; exit 1
    fi
  fi
done < <(find build/package/Payload -type f -print0)
find build/package/Payload -type d -name _CodeSignature -prune -exec rm -rf '{}' +
find build/package/Payload -name embedded.mobileprovision -delete
executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Info.plist")"
lipo -archs "$app/$executable" | grep -qw arm64
(cd build/package && ditto -c -k --keepParent Payload ../pro-image-editor-unsigned.ipa)
python3 - <<'PY'
import plistlib, zipfile
with zipfile.ZipFile('build/pro-image-editor-unsigned.ipa') as z:
    assert z.testzip() is None
    p = plistlib.loads(z.read('Payload/Runner.app/Info.plist'))
    assert p['CFBundleIdentifier'] == 'com.manhwa.proimageeditortrial'
    assert any('flutter_assets' in n for n in z.namelist())
    assert not any('/_CodeSignature/' in n or n.endswith('embedded.mobileprovision') for n in z.namelist())
    print('Unsigned ARM64 IPA verified:', p['CFBundleIdentifier'], p.get('MinimumOSVersion'))
PY
shasum -a 256 build/pro-image-editor-unsigned.ipa > build/pro-image-editor-unsigned.ipa.sha256
