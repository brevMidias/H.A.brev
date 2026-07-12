#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Starting Home Assistant Core..."
echo ""

if command -v termux-wake-lock &>/dev/null; then
    termux-wake-lock
    echo "[*] Wake lock acquired."
fi

PHONE_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

echo "-----------------------------------------------------"
echo "  Home Assistant is starting up."
echo ""
echo "  First launch takes 5-10 minutes to initialize."
echo "  When ready, open in your browser:"
echo ""
echo "    http://${PHONE_IP:-localhost}:8123"
echo ""
echo "  Press Ctrl+C to stop."
echo "-----------------------------------------------------"
echo ""

proot-distro login ubuntu -- "/data/data/com.termux/files/home/hass-venv/bin/hass" -c "/data/data/com.termux/files/home/hass-config"
