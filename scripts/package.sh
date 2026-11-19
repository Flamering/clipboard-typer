#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="1.0.0"
WV2_VERSION="1.0.4314.35"
NUPKG="https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/${WV2_VERSION}/microsoft.web.webview2.${WV2_VERSION}.nupkg"

mkdir -p build dist/payload

if [ ! -f build/webview2.nupkg ]; then
  curl -fsSL --max-time 90 "$NUPKG" -o build/webview2.nupkg
fi

python3 - <<'PY'
import zipfile
with zipfile.ZipFile('build/webview2.nupkg') as z:
    data = z.read('build/native/x64/WebView2Loader.dll')
with open('build/WebView2Loader.dll', 'wb') as f:
    f.write(data)
PY

if command -v Ahk2Exe.exe >/dev/null 2>&1; then
  Ahk2Exe.exe /in src/ClipboardTyper.ahk /out dist/payload/ClipboardTyper.exe
else
  cp src/ClipboardTyper.ahk dist/payload/ClipboardTyper.exe
  printf 'PLACEHOLDER: compilar src/ClipboardTyper.ahk con Ahk2Exe en Windows.\n' > dist/payload/BUILD-NOTE.txt
  echo "WARN: compilar en Windows con Ahk2Exe" >&2
fi

cp src/ui.html dist/payload/ui.html
cp src/bridge.testable.js dist/payload/bridge.testable.js
cp build/WebView2Loader.dll dist/payload/WebView2Loader.dll
cp README.md dist/payload/README.md

python3 - "$VERSION" <<'PY'
import os, sys, zipfile
version = sys.argv[1]
out = f'dist/ClipboardTyper-v{version}.zip'
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir('dist/payload')):
        z.write(os.path.join('dist/payload', name), name)
print(f'zip: {out} ({os.path.getsize(out)} bytes)')
PY
