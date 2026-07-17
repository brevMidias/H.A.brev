#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "[*] Starting Home Assistant Core..."
echo ""

if command -v termux-wake-lock &>/dev/null; then
    termux-wake-lock
    echo "[*] Wake lock acquired."
fi

PHONE_IP=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# --- Guardião do log (rede de segurança) --------------------------------------
# O home-assistant.log só rotaciona no restart. Se alguma integração entrar em
# loop de erro (ex.: bug de socket EINVAL no proot), o log pode crescer sem
# limite e lotar o armazenamento interno do celular. Este watchdog roda em
# segundo plano e trunca o log caso ele passe de 500 MB, checando a cada 5 min.
LOG_FILE="/data/data/com.termux/files/home/hass-config/home-assistant.log"
LOG_MAX_BYTES=524288000  # 500 MB
(
    while true; do
        sleep 300
        if [ -f "$LOG_FILE" ]; then
            SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
            if [ "$SIZE" -gt "$LOG_MAX_BYTES" ]; then
                : > "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [watchdog] home-assistant.log truncado (estava com $SIZE bytes)" >> "$LOG_FILE"
            fi
        fi
    done
) &
WATCHDOG_PID=$!
trap 'kill "$WATCHDOG_PID" 2>/dev/null' EXIT INT TERM

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
