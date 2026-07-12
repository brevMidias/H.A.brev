# AGENTS.md — HomeAssistent (Home Assistant no Android + integração Jarvis)

> Fonte de verdade para qualquer IA ou dev trabalhando neste repositório.
> **Leia inteiro antes de propor ou aplicar qualquer mudança.**

---

## O que é este repositório

Scripts de instalação/gerência do **Home Assistant rodando em um celular Android
antigo** (via Termux + udocker), mais os roteiros para integrar esse HA ao
assistente pessoal **Jarvis**.

As correções (bugs conhecidos, timezone, wake-lock) são feitas **direto nos scripts
deste diretório** — sem perder a configuração já feita no HA. O [README.md](README.md)
ainda é o texto de instalação original e deve ser atualizado conforme as correções.

**Objetivo final:** Jarvis consegue ligar o PC (Wake-on-LAN), acionar relé e ler
sensores do HA, através de um túnel WireGuard fixo entre a VPS (onde o Jarvis roda)
e o celular (onde o HA roda).

---

## ⚠️ Onde vive o código do Jarvis (repositório separado)

O Jarvis **não está neste repositório**. O código dele fica em:

```
D:\Jarvis-NIKO\JarvisServer
```

Esse diretório já está listado como *additional working directory* nesta sessão —
você pode lê-lo diretamente. Antes de mexer em qualquer coisa de integração,
consulte a fonte de verdade dele: `D:\Jarvis-NIKO\JarvisServer\AGENTS.md`.

**Resumo do Jarvis (confirmado lendo o código):**

- **JarvisServer** (raiz) — monolito Node.js/TypeScript (Express + WebSocket + MQTT
  + SQLite). Voz (Gemini Live), Telegram, WhatsApp, IoT, controle de PC, memória, cron.
  Hoje o **Wake-on-LAN é feito via ESP32 + MQTT** — não via HA nativo.
- **`Agent/`** — agente Python "Hermes Agent" (vendorizado, da NousResearch). **É aqui
  que mora a integração de Home Assistant de verdade.**
- **`agent_pc/`** — serviço Python FastAPI no PC Windows (ações físicas no PC).
- **`ESP32/`, `Alexa_ESP32/`, `firmware/`** — firmwares Arduino/ESP-IDF.

---

## Como o Jarvis fala com o Home Assistant (estado real do código)

A integração HA funcional está no agente Python, nestes arquivos:

| Arquivo (em `D:\Jarvis-NIKO\JarvisServer`) | Papel |
|---|---|
| `Agent/tools/homeassistant_tool.py` | 4 tools LLM via **REST**: `ha_list_entities`, `ha_get_state`, `ha_list_services`, `ha_call_service` |
| `Agent/plugins/platforms/homeassistant/adapter.py` | Adapter **WebSocket**: assina `state_changed`, envia notificações via REST |
| `Agent/plugins/platforms/homeassistant/plugin.yaml` | Manifesto do plugin de plataforma |
| `Agent/tests/gateway/test_homeassistant.py`, `Agent/tests/tools/test_homeassistant_tool.py`, `Agent/tests/integration/test_ha_integration.py`, `Agent/tests/fakes/fake_ha_server.py` | Testes + servidor HA fake |

### Contrato de configuração (variáveis de ambiente)

> ⚠️ **Atenção ao nome das variáveis.** O código do Jarvis usa **`HASS_URL`** e
> **`HASS_TOKEN`**. O roteiro [.claude/setup-ha-android-jarvis.md](.claude/setup-ha-android-jarvis.md)
> escreve `HA_URL` / `HA_TOKEN` — nomes **diferentes** dos que o código lê. Ao
> configurar de verdade, use os nomes do código (`HASS_*`) ou ajuste o roteiro.

- `HASS_TOKEN` — Long-Lived Access Token do HA (obrigatório; sem ele as tools ficam desabilitadas).
- `HASS_URL` — URL base HTTP do HA. Default: `http://homeassistant.local:8123`.
  Para o cenário deste projeto, aponte pro IP interno do WireGuard, ex.
  `http://10.8.0.3:8123`. O adapter converte `http→ws` sozinho para o WebSocket
  (`ws://.../api/websocket`).

### Wake-on-LAN pelo caminho nativo do HA

O agente Python **não tem código específico de WOL** (confirmado: nenhum match para
`wake_on_lan`/`send_magic_packet` em `Agent/`). O caminho nativo é genérico via
`ha_call_service`, depois que a integração "Wake on LAN" estiver configurada no HA:

```
ha_call_service(domain="wake_on_lan", service="send_magic_packet",
                data='{"mac": "XX:XX:XX:XX:XX:XX"}')
```

O exemplo em Node/`ws` no roteiro (`type: "call_service"` cru no WebSocket) é
**ilustrativo/aspiracional** — não existe ainda um cliente HA no servidor Node.
Prefira usar/estender a integração Python que já é testada.

### Segurança da integração (não afrouxe sem motivo)

`homeassistant_tool.py` implementa proteções que **devem ser preservadas**:

- **Domínios bloqueados** em `ha_call_service`: `shell_command`, `command_line`,
  `python_script`, `pyscript`, `hassio`, `rest_command` (execução arbitrária / SSRF).
- **Validação de formato** de `domain`/`service`/`entity_id` por regex antes de montar
  a URL (previne path traversal em `/api/services/{domain}/{service}`).
- O token é um segredo — **nunca** ecoe o valor de `HASS_TOKEN` em logs ou respostas.

---

## Os scripts deste repositório

Todos rodam em **Termux** (Android) e usam **udocker** (Docker sem root) — as funções
utilitárias ficam em [source.env](source.env), que os outros scripts dão `source`.

| Script | O que faz |
|---|---|
| [home-assistant-core.sh](home-assistant-core.sh) | Baixa a imagem `homeassistant/home-assistant:stable` e roda via udocker. Porta `8123`. |
| [install_udocker.sh](install_udocker.sh) | Instala/prepara o udocker no Termux. |
| [matter-server.sh](matter-server.sh) | Sobe o Python Matter Server (`ws://localhost:5580/ws`). |
| [music-assistant.sh](music-assistant.sh) | Sobe o Music Assistant (container udocker — leia antes de mexer). |
| [wyoming-microwake-word.sh](wyoming-microwake-word.sh) | Sobe o Wyoming microWakeWord (wake word por voz). |
| [source.env](source.env) | Funções udocker (`udocker_check`, `udocker_create`, `udocker_run`, patches proot/qemu). Sourced pelos demais. |

**Parâmetros importantes de [home-assistant-core.sh](home-assistant-core.sh):**

- `TZ="Asia/Seoul"` na linha 9 — **trocar para `America/Bahia`**.
- `STORAGE_PATH="$(pwd)/haconfig"` (linha 12) — config do HA fica em **`./haconfig`**,
  relativo ao diretório onde o script roda. **São os dados reais; não apague.**
- `PORT` — default `8123` (só aceita 1024–65535).
- Imagem: **HA Container** (`homeassistant/home-assistant:stable`), rodado como
  `python3 -m homeassistant --config /config`.

### ⚠️ Discrepância entre os scripts e o roteiro — VERIFIQUE antes de agir

O código dos scripts e o roteiro [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md)
descrevem **métodos de instalação diferentes**. Não assuma; confirme o que está
rodando de fato no celular:

| Aspecto | Scripts deste repo (real) | Roteiro `proximos-passos` |
|---|---|---|
| Runtime | **udocker** (imagem Docker do HA) | `proot-distro ubuntu` + venv |
| Config | `./haconfig` | `~/hass-config` |
| Ambiente Python | (dentro do container) | `~/hass-venv` |

O fix de onboarding proposto no roteiro mexe em `.storage/onboarding` — esse arquivo
existe nos dois métodos, mas **o caminho até ele muda** conforme o runtime. Antes de
automatizar qualquer fix, descubra qual instalação está ativa e ajuste os caminhos.

---

## "Addons" = containers udocker irmãos (não add-ons de verdade)

Esta instalação é **Home Assistant Container** (imagem `homeassistant/home-assistant:stable`),
que **não tem o Supervisor**. Portanto **não existe a loja de Add-ons** do HA OS/Supervised.

O que aqui chamamos de "addon" é, na prática, **outro container udocker rodando ao lado**
do HA — o mesmo padrão dos scripts que já existem neste repo:

| "Addon" | Script | HA conecta via |
|---|---|---|
| Matter Server | [matter-server.sh](matter-server.sh) | integração Matter, `ws://localhost:5580/ws` |
| Music Assistant | [music-assistant.sh](music-assistant.sh) | integração Music Assistant, `localhost:8095` |
| Wyoming microWakeWord | [wyoming-microwake-word.sh](wyoming-microwake-word.sh) | Wyoming, `localhost:10400` |

**Por que `localhost` funciona entre containers:** o udocker (baseado em proot) **não isola
a rede** — todos os containers compartilham a pilha de rede do próprio Android. O HA alcança
os outros containers por `localhost:PORTA`, e pacotes saem pela interface Wi-Fi real do
celular (é o que também faz o Wake-on-LAN nativo alcançar a LAN).

**Regras ao adicionar um novo "addon" (container):**
- Criar um script no **mesmo padrão** dos existentes: `source source.env` → `udocker_check`
  → `udocker_prune` → `udocker_create "$NOME" "$IMAGEM"` → `udocker_run -p PORTA:PORTA ...`.
  Rodar em uma sessão Termux separada (ou `screen`), já que cada `udocker_run` bloqueia o terminal.
- Escolher **porta livre**. Já em uso: HA `8123`, Matter `5580`, Music Assistant `8095`,
  Wyoming `10400`.
- Persistir dados em volume no host (`-v "$STORAGE_PATH:/data"`) pra não perder config na recriação.
- No HA, **adicionar a integração manualmente por IP/porta** (`localhost:PORTA` ou o IP do
  celular) — a auto-descoberta (mDNS) **não funciona** no udocker (bug zeroconf abaixo).

---

## Bugs conhecidos (contexto para não repetir esforço)

- **Onboarding travado em "Analytics"** — `Failed to save: Unknown command` em instalação
  Core/Container (sem Supervisor). Fix: injetar `"analytics"` e `"integration"` em
  `.storage/onboarding` após o primeiro boot (issues #126304, #165242 do home-assistant/core).
  Detalhes e trecho de código: [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md).
- **Zeroconf/SSDP** — `No adapter found for IP address fe80::` no ambiente udocker/proot
  (rede emulada). **Sempre adicione integrações manualmente por IP**, nunca dependa de
  auto-descoberta (mDNS).
- **Termux morto pelo Android** — em alguns fabricantes (Xiaomi/MIUI, Samsung) mesmo com
  `termux-wake-lock`. Desativar otimização de bateria; considerar `termux-boot`.

---

## Roadmap / próximos passos

Dois documentos guiam o trabalho (leia o relevante antes de executar):

- [.claude/setup-ha-android-jarvis.md](.claude/setup-ha-android-jarvis.md) — roteiro
  completo: WireGuard (celular↔VPS) → Termux/udocker/HA → ESPHome (relé) → Jarvis↔HA.
- [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md) —
  **Fase 1:** correção dos scripts (timezone, fix de onboarding automático,
  `termux-wake-lock` no start, documentar path real). **Fase 2:** Wake-on-LAN **nativo**
  do HA (`wake_on_lan.send_magic_packet`) — sem ESP32 como ponte, para tirar um hop
  da cadeia (`Jarvis → HA → PC` em vez de `Jarvis → HA → ESP32 → PC`).

Topologia de rede alvo: o **celular sempre inicia** o WireGuard até a VPS (outbound),
então o IP público dinâmico do roteador de casa nunca precisa ser conhecido.

---

## Convenções e regras de segurança

- **Nunca perca dados de configuração do HA.** `./haconfig` (ou `~/hass-config`)
  contém usuário, onboarding e dispositivos. Ao trocar scripts, confirme que os
  caminhos apontam pros mesmos dados **antes** de rodar.
- **Scripts são Bash de Termux** (`#!/data/data/com.termux/files/usr/bin/bash`).
  Mantenha compatibilidade POSIX/Termux; não introduza dependências que não existem
  no Termux sem instalar via `pkg`/`pip`.
- **WOL só funciona na mesma sub-rede** (broadcast UDP não atravessa VLAN/sub-rede sem
  IP Helper no roteador) e só com o PC em soft-off (S5) com energia em standby.
- **Ações destrutivas** (apagar containers, `haconfig`, resetar HA) exigem confirmação
  explícita do usuário. Prefira alternativas não-destrutivas.
- **Segredos** (tokens HA, chaves WireGuard, senhas OTA/API ESPHome) nunca vão pro
  git nem aparecem em respostas. Referencie por nome, não por valor.
- Use as **ferramentas dedicadas** (leitura/edição/busca) em vez de `cat`/`sed`/`grep`
  no shell, para dar visibilidade ao usuário.

---

## Fontes de verdade

- Este `AGENTS.md` — guia deste repo.
- [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md) e
  [.claude/setup-ha-android-jarvis.md](.claude/setup-ha-android-jarvis.md) — roadmap.
- [README.md](README.md) — texto de instalação original.
- `D:\Jarvis-NIKO\JarvisServer\AGENTS.md` — fonte de verdade do Jarvis (repo separado).
