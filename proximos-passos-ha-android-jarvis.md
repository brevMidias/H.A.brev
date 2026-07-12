# Próximos passos: Fork do repositório + Wake-on-LAN nativo do HA

## Contexto para o Claude Code

Já temos um Home Assistant Core funcional rodando no celular Android via
Termux + proot-distro (Ubuntu), instalado a partir do repositório
https://github.com/huytungst/HomeAssistant-Termux. Durante a instalação,
encontramos e corrigimos manualmente 2 bugs que o repositório original não
resolve. Agora vamos: (1) fazer fork do repo, aplicar essas correções direto
nos scripts, subir pro nosso próprio repositório, e trocar a instalação atual
pra usar os scripts corrigidos — sem perder a configuração já feita (usuário,
onboarding, etc). (2) Ligar o PC remotamente via Wake-on-LAN, usando a
integração **nativa** do Home Assistant (`wake_on_lan.send_magic_packet`) —
sem depender do ESP32 como ponte.

> Nota sobre a decisão de não usar o ESP32 pra isso: Wake-on-LAN é só um
> pacote UDP de broadcast na rede local. Como o Home Assistant já roda dentro
> da própria rede local (no celular, na mesma Wi-Fi do PC), ele mesmo pode
> enviar esse pacote diretamente — sem precisar de um dispositivo
> intermediário (ESP32) fazendo a ponte. Isso elimina um hop
> (Jarvis → HA → ESP32 → PC vira Jarvis → HA → PC), reduzindo latência.
> O ESP32 continua útil pro que já faz hoje (bridge BLE, Tuya local, relé),
> só não entra nessa parte específica.

---

## Fase 1 — Fork e correção do repositório

### 1.1 Fork pelo GitHub (interface web, não CLI)

Acessar https://github.com/huytungst/HomeAssistant-Termux e clicar em
**Fork**, apontando pra conta do Uanderson. Isso mantém o vínculo com o
repositório original (útil já que ele tem uma seção "Known Issue" aberta que
nós já resolvemos, e pode fazer sentido contribuir de volta depois).

### 1.2 Clonar o fork (não o original)

```bash
git clone https://github.com/SEU_USUARIO/HomeAssistant-Termux.git
cd HomeAssistant-Termux
```

### 1.3 Editar `home-assistant-core.sh`

Ajustes a fazer no script:

- **Timezone**: trocar `TZ="Asia/Seoul"` (ou o valor default do script) por
  `TZ="America/Bahia"`
- **Fix automático do bug de onboarding travado em Analytics**: adicionar, ao
  final do script (depois de o container/venv subir pela primeira vez), uma
  checagem que já injeta `"analytics"` e `"integration"` no arquivo
  `.storage/onboarding` assim que ele existir, evitando o erro
  `Failed to save: Unknown command` (causado pela falta do Supervisor em
  instalação tipo Core — issues #126304 e #165242 no home-assistant/core)

  Trecho de referência a incluir no script:
  ```bash
  ONBOARDING_FILE="${STORAGE_PATH:-$HOME/hass-config}/.storage/onboarding"

  fix_onboarding_analytics() {
    # Espera o arquivo de onboarding existir (criado após o usuário admin ser criado)
    for i in $(seq 1 60); do
      [ -f "$ONBOARDING_FILE" ] && break
      sleep 5
    done
    if [ -f "$ONBOARDING_FILE" ]; then
      if ! grep -q '"analytics"' "$ONBOARDING_FILE"; then
        python3 - "$ONBOARDING_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
done = data["data"]["done"]
for step in ("analytics", "integration"):
    if step not in done:
        done.append(step)
with open(path, "w") as f:
    json.dump(data, f)
PYEOF
        echo "[*] Onboarding analytics bug corrigido automaticamente."
      fi
    fi
  }
  ```
  Chamar essa função em background logo depois do `hass` subir (ex: com
  `fix_onboarding_analytics &` antes do processo principal bloquear o
  terminal), ou como um script separado documentado no README pra rodar
  manualmente após a primeira instalação.

- **Wake-lock automático**: incluir `termux-wake-lock` diretamente no início
  do script de start (já fazemos isso manualmente hoje).

### 1.4 Documentar no README do fork

Adicionar uma seção explicando:
- Que o config real fica em `/data/data/com.termux/files/home/hass-config`
  dentro do ambiente `proot-distro ubuntu` (o README original não deixa isso
  claro)
- O bug conhecido de zeroconf/ssdp (`No adapter found for IP address fe80::`)
  e que a solução é sempre adicionar integrações manualmente por IP, nunca
  esperar auto-descoberta
- O fix do onboarding trancado em Analytics

### 1.5 Subir pro repositório próprio

```bash
git add .
git commit -m "Fix: onboarding analytics travado (sem Supervisor), timezone, wake-lock automatico, documentacao do path real (proot-distro)"
git push -u origin main
```

### 1.6 Trocar a instalação atual pelos scripts corrigidos (sem perder dados)

O HA já está configurado (onboarding feito, usuário criado) em
`~/hass-config` e `~/hass-venv` — não precisamos reinstalar, só trocar os
scripts de gerenciamento:

```bash
bash ~/stop-homeassistant.sh
mv ~/HomeAssistant-Termux ~/HomeAssistant-Termux-original
git clone https://github.com/SEU_USUARIO/HomeAssistant-Termux.git
```

Os novos scripts devem apontar pros mesmos caminhos (`~/hass-config`,
`~/hass-venv`) — conferir isso antes de rodar, já que são os dados reais que
não podem ser perdidos. Testar:

```bash
cd ~/HomeAssistant-Termux
bash home-assistant-core.sh   # ou o nome do script de start atualizado
```

Confirmar que o HA sobe normalmente e que a configuração/dispositivos
continuam lá.

---

## Fase 2 — Wake-on-LAN nativo do Home Assistant (sem ESP32)

O Home Assistant já roda dentro da rede local (no celular, na mesma Wi-Fi do
PC), então ele mesmo pode enviar o pacote WOL diretamente — não precisa de um
dispositivo intermediário. Menos um hop na cadeia = menos latência:

```
Antes (com ESP32):  Jarvis → HA → API ESPHome → ESP32 → pacote WOL → PC
Agora (nativo):      Jarvis → HA → pacote WOL → PC
```

O ESP32 já existente continua fazendo o que já fazia (bridge BLE, Tuya
local, relé) — só não entra nessa parte.

### 2.1 Pré-requisito: habilitar Wake-on-LAN no PC

- **BIOS/UEFI**: habilitar "Wake on LAN" ou "Power On by PCI-E/PCI" nas
  configurações de energia
- **Sistema operacional**:
  - Windows: Gerenciador de Dispositivos → Adaptador de rede → Propriedades →
    Gerenciamento de Energia → marcar "Permitir que este dispositivo ative o
    computador" e "Somente permitir um pacote mágico"
  - Linux: `sudo ethtool -s <interface> wol g` (e criar serviço systemd pra
    persistir após reboot, já que a config pode resetar)
- **Anotar o endereço MAC** da placa de rede do PC:
  - Windows: `ipconfig /all`
  - Linux: `ip link show`

### 2.2 Adicionar a integração Wake on LAN no Home Assistant

Pela UI (mais simples):

1. Configurações → Dispositivos e Serviços → Adicionar Integração
2. Buscar **"Wake on LAN"**
3. Informar o MAC address do PC anotado no passo 2.1

Isso cria automaticamente uma entidade tipo `button.wake_on_lan_pc` (o nome
exato depende da versão do HA).

Alternativa via YAML, editando
`/data/data/com.termux/files/home/hass-config/configuration.yaml` (dentro do
proot-distro ubuntu):
```yaml
button:
  - platform: wake_on_lan
    name: "Ligar PC"
    mac_address: "XX:XX:XX:XX:XX:XX"   # MAC do PC anotado no passo 2.1
```
Se for por YAML, reiniciar o HA depois de salvar (`bash ~/stop-homeassistant.sh`
e `bash ~/start-homeassistant.sh`).

### 2.3 Testar manualmente

Pela UI do HA, clicar no botão "Ligar PC" e confirmar que o PC liga. Se não
ligar:
- Confirmar que o PC estava desligado por software (soft-off / modo S5), e
  não com o cabo de energia desconectado — WOL só funciona com a placa mãe
  ainda recebendo energia em standby
- Confirmar que o PC e o celular (rodando o HA) estão na mesma sub-rede — WOL
  via broadcast normalmente não atravessa VLANs/sub-redes diferentes sem
  configuração extra no roteador (feature costuma se chamar "IP Helper")

### 2.4 Integrar no Jarvis

Assim que o relé (Fase B do roteiro anterior) e o Wake-on-LAN estiverem
validados na UI do HA, o Jarvis chama o serviço via WebSocket API:

```json
{
  "id": 2,
  "type": "call_service",
  "domain": "wake_on_lan",
  "service": "send_magic_packet",
  "service_data": { "mac": "XX:XX:XX:XX:XX:XX" }
}
```

Se preferir usar a entidade `button` criada pela UI em vez do serviço direto:
```json
{
  "id": 2,
  "type": "call_service",
  "domain": "button",
  "service": "press",
  "target": { "entity_id": "button.wake_on_lan_pc" }
}
```

---

## Checklist final desta etapa

- [ ] Fork criado e scripts corrigidos commitados no repositório próprio
- [ ] Instalação atual trocada pros scripts do fork, sem perder configuração
- [ ] Fix do onboarding automatizado (não precisa mais editar `.storage/onboarding` na mão)
- [ ] Wake-on-LAN habilitado no BIOS/SO do PC, MAC anotado
- [ ] Integração "Wake on LAN" adicionada no HA (via UI ou YAML), sem envolver o ESP32
- [ ] Botão testado manualmente pela UI do HA — PC liga de fato
- [ ] Jarvis capaz de chamar `wake_on_lan.send_magic_packet` (ou `button.press`) via WebSocket API
