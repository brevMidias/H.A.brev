#!/data/data/com.termux/files/usr/bin/bash
set -e
CONFIG="$HOME/hass-config"

echo "=== connectivity check ==="
curl -sI https://github.com -o /dev/null -w "github reachable: HTTP %{http_code}\n" || echo "github UNREACHABLE"

echo "=== prepare custom_components ==="
mkdir -p "$CONFIG/custom_components"
cd "$CONFIG/custom_components"
if [ -d hacs ]; then echo "existing hacs dir found, will replace"; fi

echo "=== download latest hacs.zip ==="
wget -q -O hacs.zip https://github.com/hacs/integration/releases/latest/download/hacs.zip
echo "downloaded size: $(du -h hacs.zip | cut -f1)"

echo "=== extract ==="
rm -rf hacs
mkdir -p hacs
unzip -o -q hacs.zip -d hacs
rm -f hacs.zip

echo "=== verify ==="
echo "files in hacs/:"
ls hacs | head -20
echo "--- manifest.json domain/version ---"
grep -E '"domain"|"version"' hacs/manifest.json 2>/dev/null || echo "manifest NOT found!"
echo "=== DONE ==="
