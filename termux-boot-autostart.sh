#!/data/data/com.termux/files/usr/bin/sh
# Auto-start no boot (Termux:Boot): wake-lock + sshd + Home Assistant.
# Requer o app Termux:Boot instalado e o Termux fora da otimizacao de bateria.
#
# Instalar no celular copiando este arquivo para:
#   ~/.termux/boot/boot-autostart.sh
# e dando permissao de execucao (chmod +x). Normalize CRLF->LF se editar no Windows.

HOME_DIR=/data/data/com.termux/files/home
LOGF="$HOME_DIR/boot-autostart.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') [boot] iniciando" >> "$LOGF"

# 1) Mantem o CPU acordado
termux-wake-lock

# 2) Sobe o servidor SSH (se ainda nao estiver rodando)
pgrep -x sshd >/dev/null 2>&1 || sshd
echo "$(date '+%Y-%m-%d %H:%M:%S') [boot] sshd ok" >> "$LOGF"

# 3) Espera a rede/WiFi estabilizar
sleep 25

# 4) Sobe o Home Assistant (destacado), se ainda nao estiver rodando
if ! pgrep -f "bin/hass" >/dev/null 2>&1; then
    setsid sh -c "nohup bash $HOME_DIR/start-homeassistant.sh > $HOME_DIR/ha-boot.out 2>&1" </dev/null &
    echo "$(date '+%Y-%m-%d %H:%M:%S') [boot] HA disparado" >> "$LOGF"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [boot] HA ja rodando" >> "$LOGF"
fi
