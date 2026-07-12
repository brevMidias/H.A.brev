#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/source.env"

# Mantem a CPU acordada para o Android nao suspender/matar o Home Assistant com
# a tela apagada. Requer o pacote termux-api (pkg install termux-api).
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock

# The script will find and download the image from Docker Hub, not from GitHub Container Registry
IMAGE_NAME="homeassistant/home-assistant:stable"
CONTAINER_NAME="home-assistant-core"

# Set timezone. Feel free to change.
TZ="America/Bahia"

# Set storage path for Home Assistant configuration
STORAGE_PATH="$(pwd)/haconfig"
mkdir -p "$STORAGE_PATH"

# --- Fix: onboarding travado na etapa "Analytics" -------------------------
# Em instalacoes Core/Container (sem Supervisor), a etapa de Analytics do
# onboarding falha com "Failed to save: Unknown command" e trava a conclusao
# (issues #126304 / #165242 do home-assistant/core). Assim que o arquivo de
# onboarding existir e o usuario admin tiver sido criado, injetamos as etapas
# "analytics" e "integration" como concluidas para destravar.
ONBOARDING_FILE="${STORAGE_PATH}/.storage/onboarding"

fix_onboarding_analytics() {
  PY="$(command -v python3 || command -v python)"
  [ -n "$PY" ] || return 0

  # Poll por ~5 min: espera o arquivo existir e (apos a etapa "user") marca
  # "analytics"/"integration" como feitas. No-op se ja estiverem concluidas.
  for _ in $(seq 1 60); do
    if [ -f "$ONBOARDING_FILE" ]; then
      if "$PY" - "$ONBOARDING_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
    done = data.get("data", {}).get("done", [])
    if "user" not in done:
        sys.exit(1)  # usuario admin ainda nao criado -- continua aguardando
    changed = False
    for step in ("analytics", "integration"):
        if step not in done:
            done.append(step)
            changed = True
    if changed:
        with open(path, "w") as f:
            json.dump(data, f)
    sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF
      then
        echo "[*] Onboarding: etapas 'analytics'/'integration' concluidas automaticamente."
        return 0
      fi
    fi
    sleep 5
  done
}
# --------------------------------------------------------------------------

# Check if PORT is a valid number; default to 8123 if not provided
case $PORT in
  ''|*[!0-9]*) PORT=8123;;
  *) [ $PORT -gt 1023 ] && [ $PORT -lt 65536 ] || PORT="8123";;
esac

# Ensure udocker environment is set up
udocker_check

# Clean up unused containers and images
udocker_prune

# Create the Home Assistant container
udocker_create "$CONTAINER_NAME" "$IMAGE_NAME"

# If arguments are passed, run them directly in the container
if [ -n "$1" ]; then
 udocker_run --entrypoint "bash -c" -p "$PORT:8123" "$CONTAINER_NAME" "$@"
else
  # Corrige o bug de onboarding (Analytics) em background enquanto o HA sobe.
  fix_onboarding_analytics &

  # Default run command for Home Assistant with configuration
 udocker_run -p "$PORT:8123" \
   -e TZ="$TZ" \
   -v "$STORAGE_PATH:/config" \
  "$CONTAINER_NAME" \
  bash -c 'exec python3 -m homeassistant --config /config'
fi
exit $?
