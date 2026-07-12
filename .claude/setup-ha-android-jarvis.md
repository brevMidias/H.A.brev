# Roteiro: Home Assistant no Android + WireGuard + ESPHome (relé) + Jarvis

Objetivo final: Jarvis (rodando na VPS Oracle) consegue falar com o Home Assistant
(rodando no celular Android via Termux) através de um túnel WireGuard fixo, e
automatizar um relé conectado via ESPHome (ex: ligar/desligar lâmpada).

Contexto de rede: o roteador de casa muda de IP público com frequência e não
há acesso admin a ele. Por isso a estratégia é: o celular é sempre quem inicia
a conexão WireGuard até a VPS (outbound), então o IP dinâmico do roteador nunca
precisa ser conhecido ou fixo.

---

## Fase 0 — Pré-requisitos

- [ ] VPS Oracle já operante, com WireGuard instalável (ou já instalado, se for
      reaproveitar o túnel que o Jarvis já usa)
- [ ] Celular Android antigo, carregador conectado (vai ficar ligado o tempo todo)
- [ ] Wi-Fi estável em casa
- [ ] App **Termux** — instalar via F-Droid (NÃO usar a versão da Play Store,
      está desatualizada e sem suporte)
- [ ] App **WireGuard** oficial — instalar via F-Droid ou Play Store
- [ ] Placa ESP32/ESP8266 + módulo relé (ex: relé 1 canal 5V/3.3V) + jumpers
- [ ] Cabo USB pra flashar o firmware na placa a partir de um PC (ou fazer
      via OTA depois do primeiro flash)

---

## Fase 1 — WireGuard: celular ↔ VPS

**Na VPS** (onde o Jarvis já roda):

1. Se o WireGuard ainda não estiver instalado na VPS:
   ```
   sudo apt update && sudo apt install wireguard -y
   ```
2. Gerar par de chaves do servidor (se ainda não existir):
   ```
   wg genkey | tee server_private.key | wg pubkey > server_public.key
   ```
3. Gerar par de chaves específico pro celular:
   ```
   wg genkey | tee phone_private.key | wg pubkey > phone_public.key
   ```
4. Adicionar o peer do celular na config do servidor (`/etc/wireguard/wg0.conf`):
   ```
   [Peer]
   PublicKey = <conteúdo de phone_public.key>
   AllowedIPs = 10.8.0.3/32
   ```
5. Reiniciar o WireGuard na VPS:
   ```
   sudo systemctl restart wg-quick@wg0
   ```

**No celular** (app WireGuard, não Termux):

6. Criar novo túnel manualmente (ou importar via QR code gerado na VPS) com:
   ```
   [Interface]
   PrivateKey = <conteúdo de phone_private.key>
   Address = 10.8.0.3/32
   DNS = 1.1.1.1

   [Peer]
   PublicKey = <conteúdo de server_public.key>
   Endpoint = <IP_OU_DOMINIO_DA_VPS>:51820
   AllowedIPs = 10.8.0.0/24
   PersistentKeepalive = 25
   ```
7. Ativar o túnel e confirmar handshake (o app WireGuard mostra "latest
   handshake" recente).
8. Testar da VPS: `ping 10.8.0.3` — precisa responder.

> Por que `PersistentKeepalive = 25`: mantém o túnel vivo através de NAT/CGNAT
> da operadora/roteador, evitando que a conexão caia por inatividade.

---

## Fase 2 — Termux + udocker + Home Assistant Container

**No Termux:**

1. Atualizar pacotes e instalar dependências:
   ```
   pkg update && pkg upgrade -y
   pkg install git python -y
   pip install udocker
   udocker install
   ```
2. Testar udocker:
   ```
   udocker run hello-world
   ```
3. Clonar o projeto de referência (huytungst/HomeAssistant-Termux) ou criar o
   container manualmente:
   ```
   git clone https://github.com/huytungst/HomeAssistant-Termux
   cd HomeAssistant-Termux
   ```
4. Rodar o script de instalação do Home Assistant Core (ajustar TZ pra
   `America/Bahia` ou equivalente dentro do script antes de rodar):
   ```
   bash home-assistant-core.sh
   ```
5. Confirmar que o HA subiu, acessando pelo navegador do próprio celular:
   `http://localhost:8123`
6. Fazer o onboarding inicial do HA (criar usuário admin).

**Manter rodando em background:**

7. Instalar wake-lock pra evitar que o Android mate o processo:
   ```
   pkg install termux-api
   termux-wake-lock
   ```
8. Desativar otimização de bateria do Termux nas configurações do Android
   (Configurações → Apps → Termux → Bateria → Sem restrições).

---

## Fase 3 — ESPHome + relé

Como esse é Home Assistant Container (sem Supervisor), não existe o ESPHome
add-on com dashboard integrado. Duas opções:

**Opção A — ESPHome via container separado (recomendado)**
No mesmo Termux, outra sessão (`screen`):
```
udocker pull esphome/esphome
udocker create --name=esphome esphome/esphome
udocker run -p 6052:6052 -v $(pwd)/esphome-config:/config esphome esphome dashboard /config
```
Acessar `http://localhost:6052` no navegador do celular pra criar o YAML do
dispositivo.

**Opção B — ESPHome via pip, direto no PC** (mais simples pra primeiro flash)
```
pip install esphome
esphome dashboard config/
```

**YAML de exemplo pro relé** (ajustar pino conforme a placa/módulo relé usado):
```yaml
esphome:
  name: rele-sala

esp32:
  board: esp32dev
  framework:
    type: arduino

wifi:
  ssid: "SEU_WIFI"
  password: "SUA_SENHA"

api:
  encryption:
    key: "GERAR_CHAVE_AQUI"

ota:
  password: "SENHA_OTA"

switch:
  - platform: gpio
    pin: GPIO26
    name: "Rele Sala"
    id: rele_sala
```

- [ ] Compilar e flashar via USB (`esphome run config/rele-sala.yaml`)
- [ ] Confirmar que o dispositivo conecta no Wi-Fi e aparece nos logs

**Adicionar o dispositivo no HA:**

Como a auto-descoberta via mDNS pode não funcionar dentro do udocker (limitação
de rede em modo bridge/emulado), adicionar manualmente:

1. No HA: Configurações → Dispositivos e Serviços → Adicionar Integração →
   ESPHome
2. Informar o IP do ESP32 na rede local + porta `6053`
3. Confirmar a chave de encriptação da API (a mesma do YAML)

---

## Fase 4 — Jarvis ↔ Home Assistant

**No Home Assistant** (celular):

1. Perfil do usuário admin → rolar até "Long-Lived Access Tokens" → criar um
   token novo, copiar o valor (só aparece uma vez)

**No Jarvis (VPS):**

2. Configurar a URL do HA usando o IP interno do WireGuard, não o IP da Wi-Fi
   de casa:
   ```
   HA_URL=ws://10.8.0.3:8123/api/websocket
   HA_TOKEN=<long-lived-token-gerado-acima>
   ```
3. Testar a conexão WebSocket manualmente (exemplo em Node.js, ajustar pro
   client que o Jarvis já usa):
   ```js
   const WebSocket = require('ws');
   const ws = new WebSocket('ws://10.8.0.3:8123/api/websocket');

   ws.on('open', () => {
     ws.send(JSON.stringify({ type: 'auth', access_token: process.env.HA_TOKEN }));
   });

   ws.on('message', (data) => console.log(data.toString()));
   ```
4. Confirmar que recebe `auth_ok` na resposta.
5. Testar uma automação simples: chamar o serviço `switch.turn_on` /
   `switch.turn_off` na entidade `switch.rele_sala` e confirmar que o relé
   físico aciona.

---

## Checklist final de validação

- [ ] Túnel WireGuard sobe automaticamente quando o celular liga
- [ ] `ping 10.8.0.3` responde a partir da VPS mesmo depois de trocar de Wi-Fi/rede
- [ ] HA acessível via `http://10.8.0.3:8123` a partir da VPS
- [ ] ESP32 com relé aparece como entidade `switch` no HA
- [ ] Jarvis consegue ligar/desligar o relé via WebSocket API
- [ ] Termux com wake-lock ativo e sem otimização de bateria (testar depois
      de 1h de tela apagada — HA precisa continuar respondendo)

## Riscos conhecidos (mencionar ao Claude Code se algo travar)

- Termux pode ser encerrado pelo Android mesmo com wake-lock em alguns
  fabricantes (Xiaomi/MIUI, Samsung agressivo) — pode precisar de ajuste extra
  nas configurações de bateria específicas do fabricante
- Rede do udocker é emulada (bridge), então descoberta automática (mDNS) pode
  falhar — adicionar dispositivos sempre por IP manual
- Se o celular reiniciar, tanto o túnel WireGuard quanto o HA (dentro do
  Termux) precisam subir de novo — vale automatizar com Termux:Boot
  (`pkg install termux-boot`) pra iniciar o HA automaticamente no boot
