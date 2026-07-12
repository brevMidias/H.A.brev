#!/data/data/com.termux/files/usr/bin/bash
echo "[*] Stopping Home Assistant..."

pkill -f "hass" 2>/dev/null || true

if command -v termux-wake-unlock &>/dev/null; then
    termux-wake-unlock
    echo "[*] Wake lock released."
fi

echo "[*] Home Assistant stopped."
