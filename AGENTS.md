# AGENTS.md — HomeAssistent (Home Assistant no Android + integração Jarvis)

> Fonte de verdade para qualquer IA ou dev trabalhando neste repositório.
> **Leia inteiro antes de propor ou aplicar qualquer mudança.**

---

## Acesso direto ao celular (Android/Termux) via SSH

O celular que roda o Home Assistant tem SSH disponível e o MCP `ssh-mcp` já está
configurado no C‍laude Code — o agente **pode e deve executar comandos no Termux
diretamente**, sem pedir para o usuário rodar nada manualmente.

| Parâmetro | Valor |
|---|---|
| Host | `192.168.0.4` |
| Porta | `8022` |
| Usuário | `u0_a258` |
| Chave privada | `C:\Users\Uanderson\.ssh\id_termux` |
| MCP registrado | `ssh-mcp` (stdio, via `npx -y ssh-mcp`) |

**Regras para o agente:**

- Sempre que o usuário pedir uma ação no celular/Termux/HA, execute via SSH — não
  peça para o usuário rodar o comando.
- Antes de qualquer comando destrutivo (resetar HA, apagar/recriar o container
  Ubuntu, modificar `hass-config`), confirme com o usuário.
- O diretório de dados do HA no Termux é `~/hass-config/`. **Nunca apague este
  diretório** — contém usuário, onboarding, dispositivos e o HACS instalado.
- O HA roda dentro de um container **proot-distro Ubuntu**, num venv em
  `~/hass-venv`. Para rodar comandos dentro do Ubuntu:
  `proot-distro login ubuntu -- <comando>`. Ex.: versão do HA →
  `proot-distro login ubuntu -- ~/hass-venv/bin/hass --version`.
- Start/stop do HA: `bash ~/start-homeassistant.sh` / `bash ~/stop-homeassistant.sh`.
- O sshd pode ter reiniciado se o celular foi desligado — se a conexão falhar,
  oriente o usuário a rodar `sshd` no Termux e tente novamente.

---

## O que é este repositório

Scripts de instalação/gerência do **Home Assistant rodando em um celular Android
antigo** (via Termux + **proot-distro Ubuntu**), mais os roteiros para integrar esse
HA ao assistente pessoal **Jarvis**.

As correções (bugs conhecidos, timezone, wake-lock) são feitas **direto nos scripts
deste diretório** — sem perder a configuração já feita no HA. O [README.md](README.md)
ainda é o texto de instalação original e deve ser atualizado conforme as correções.

> **Método de instalação (confirmado no celular em 2026-07-12):** proot-distro
> Ubuntu + venv Python, **não** udocker. Os scripts udocker antigos foram movidos
> para [legacy-udocker/](legacy-udocker/) — mantidos só como referência histórica,
> não são o que roda. Ver seção "Os scripts deste repositório" abaixo.

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

Todos rodam em **Termux** (Android). O HA vive dentro de um **container proot-distro
Ubuntu**, num venv Python (`~/hass-venv`). Estes são os scripts que rodam de fato no
celular (puxados de lá em 2026-07-12):

| Script | O que faz |
|---|---|
| [setup-homeassistant.sh](setup-homeassistant.sh) | Instalador completo: instala `proot-distro`, cria o Ubuntu, cria o venv `~/hass-venv`, instala o `homeassistant` via pip, aplica o patch de zeroconf (`ifaddr/_posix.py`) e gera os scripts start/stop. |
| [start-homeassistant.sh](start-homeassistant.sh) | Pega `termux-wake-lock` e sobe o HA: `proot-distro login ubuntu -- ~/hass-venv/bin/hass -c ~/hass-config`. Porta `8123`. Inclui um **watchdog de log** que trunca `home-assistant.log` se passar de 500MB (ver bug do log gigante). |
| [stop-homeassistant.sh](stop-homeassistant.sh) | `pkill -f hass` + `termux-wake-unlock`. |
| [install-hacs.sh](install-hacs.sh) | Baixa o `hass.zip` do release mais recente e extrai em `~/hass-config/custom_components/hacs/`. Rodar com o HA parado; reiniciar depois. |
| [termux-boot-autostart.sh](termux-boot-autostart.sh) | Script de auto-start no boot. Vai em `~/.termux/boot/boot-autostart.sh` no celular. Pega `termux-wake-lock`, sobe o `sshd` e o Home Assistant automaticamente quando o Android liga. **Só dispara se o app Termux:Boot estiver instalado** (ver seção "Auto-start no boot"). |

**Caminhos-chave (não apague os de dados):**

- **Config do HA:** `~/hass-config/` — usuário, onboarding, dispositivos, HACS. **Dados reais.**
- **Venv Python:** `~/hass-venv/` — o binário do HA é `~/hass-venv/bin/hass`.
- **Container:** Ubuntu do `proot-distro` (compartilha o filesystem do Termux — venv e
  config ficam no home do Termux, acessíveis de dentro e de fora do Ubuntu).
- **Porta:** `8123`. `configuration.yaml` fixa `http: server_host: 0.0.0.0` para aceitar
  conexões da LAN.
- **Timezone:** definido na configuração do HA (via UI/onboarding), não em env var de script.

**Scripts de desktop Linux** (não são do HA — deixados em [termux-desktop/](termux-desktop/)):
`termux-linux-setup.sh`, `start-linux.sh`, `stop-linux.sh`.

### Auto-start no boot (Termux:Boot)

Nem o `sshd` nem o HA sobem sozinhos após um reboot do celular. Para automatizar:

- O script [termux-boot-autostart.sh](termux-boot-autostart.sh) fica no celular em
  `~/.termux/boot/boot-autostart.sh` (já instalado e testado em 2026-07-17). Ele pega
  `termux-wake-lock`, sobe o `sshd` e dispara o `start-homeassistant.sh` (com guards
  idempotentes: não duplica processos se já estiverem rodando). Gera log em
  `~/boot-autostart.log`.
- **Pré-requisito que só o usuário faz (não dá por SSH):** instalar o app **Termux:Boot**
  pelo **F-Droid** (a versão da Play Store é obsoleta e não funciona), abrir o app uma vez
  e **tirar Termux + Termux:Boot da otimização de bateria**. Sem o app instalado/ativo, a
  pasta `~/.termux/boot/` existe mas nada é disparado no boot (foi o que aconteceu no
  reboot de 2026-07-17: `sshd` não subiu).
- Ao editar o script no Windows, normalize CRLF→LF (`sed -i 's/\r$//' ...`) senão o shebang quebra.

**Legado udocker** ([legacy-udocker/](legacy-udocker/)): `home-assistant-core.sh`,
`install_udocker.sh`, `source.env`, `matter-server.sh`, `music-assistant.sh`,
`wyoming-microwake-word.sh`. Era o plano original (rodar o HA via imagem Docker no
udocker), mas **não foi o método que funcionou** — o celular roda proot-distro.
Mantidos só como referência; não rode sem antes decidir migrar de método.

---

## "Addons" (integrações complementares)

Esta instalação é **Home Assistant Core** (rodando de pip num venv), que **não tem o
Supervisor**. Portanto **não existe a loja de Add-ons** do HA OS/Supervised — extensões
entram como **integrações** (via HACS ou nativas), não como add-ons.

O HACS já está instalado em `~/hass-config/custom_components/hacs/`. Componentes extras
(Matter Server, Music Assistant, Wyoming) rodariam como processos/containers irmãos no
mesmo Android; como o proot-distro **não isola a rede**, o HA os alcança por
`localhost:PORTA` (e é isso que também permite o Wake-on-LAN nativo alcançar a LAN).

**Regra ao adicionar integração:** **adicione manualmente por IP/porta** (`localhost:PORTA`
ou o IP do celular) — a auto-descoberta (mDNS) **não funciona** neste ambiente (bug
zeroconf abaixo). Portas de referência: HA `8123`, Matter `5580`, Music `8095`,
Wyoming `10400`.

---

## Bugs conhecidos (contexto para não repetir esforço)

- **Onboarding travado em "Analytics"** — `Failed to save: Unknown command` em instalação
  Core/Container (sem Supervisor). Fix: injetar `"analytics"` e `"integration"` em
  `.storage/onboarding` após o primeiro boot (issues #126304, #165242 do home-assistant/core).
  Detalhes e trecho de código: [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md).
- **Zeroconf/SSDP** — `No adapter found for IP address fe80::` no ambiente proot
  (rede emulada). O `setup-homeassistant.sh` já aplica um patch em
  `~/hass-venv/lib/python3.*/site-packages/ifaddr/_posix.py` para contornar. Ainda
  assim, **sempre adicione integrações manualmente por IP**, nunca dependa de
  auto-descoberta (mDNS).
- **Termux morto pelo Android** — em alguns fabricantes (Xiaomi/MIUI, Samsung) mesmo com
  `termux-wake-lock`. Desativar otimização de bateria; considerar `termux-boot`.
- **`home-assistant.log` gigante lotando o armazenamento (RESOLVIDO 2026-07-17)** — o log
  cresceu até **14GB** (disco do celular a 97%, 881MB livres) por causa de um **loop
  infinito de erro** gravado ~15-20×/s desde 12/07:
  `Error doing job: Exception in callback BaseSelectorEventLoop._accept_connection()` →
  `OSError: [Errno 22] Invalid argument`. Causa raiz: um **socket de escuta TCP** entrou
  em estado inválido no proot (rede emulada); o `epoll` sinalizava o socket como pronto,
  mas todo `accept()` falhava com `EINVAL` e o HA nunca fechava o socket quebrado (girava
  pra sempre, também torrando CPU/bateria). O único integração configurada que sobe um
  servidor TCP local é o **`upnp`** (servidor de notificação de eventos do IGD/roteador).
  Agrava: o HA **só rotaciona o `home-assistant.log` no restart** — de pé por dias, o
  arquivo cresce sem limite. **Correção aplicada:**
  1. Parar HA → zerar o log (`: > ~/hass-config/home-assistant.log`) → reclamou ~14GB.
  2. Desabilitar a integração `upnp` (`disabled_by: "user"` em
     `.storage/core.config_entries`; backup em `core.config_entries.bak`). UPnP/SSDP não
     funcionam neste ambiente mesmo — adicione tudo por IP.
  3. **Watchdog no [start-homeassistant.sh](start-homeassistant.sh):** processo em segundo
     plano que trunca o log se passar de **500MB** (checa a cada 5 min). Rede de segurança
     contra qualquer loop futuro — o disco nunca mais enche.
  > Se o loop reaparecer mesmo com `upnp` desligado, investigar outros `create_server`
  > (o próprio servidor HTTP `:8123`, ou re-bind de socket após troca de IP do WiFi).

---

## Roadmap / próximos passos

Dois documentos guiam o trabalho (leia o relevante antes de executar):

- [.claude/setup-ha-android-jarvis.md](.claude/setup-ha-android-jarvis.md) — roteiro
  completo: WireGuard (celular↔VPS) → Termux/proot-distro/HA → ESPHome (relé) → Jarvis↔HA.
- [proximos-passos-ha-android-jarvis.md](proximos-passos-ha-android-jarvis.md) —
  **Fase 1:** correção dos scripts (timezone, fix de onboarding automático,
  `termux-wake-lock` no start, documentar path real). **Fase 2:** Wake-on-LAN **nativo**
  do HA (`wake_on_lan.send_magic_packet`) — sem ESP32 como ponte, para tirar um hop
  da cadeia (`Jarvis → HA → PC` em vez de `Jarvis → HA → ESP32 → PC`).

Topologia de rede alvo: o **celular sempre inicia** o WireGuard até a VPS (outbound),
então o IP público dinâmico do roteador de casa nunca precisa ser conhecido.

---

## Convenções e regras de segurança

- **Nunca perca dados de configuração do HA.** `~/hass-config/` contém usuário,
  onboarding, dispositivos e o HACS. Ao trocar scripts, confirme que os caminhos
  apontam pros mesmos dados **antes** de rodar.
- **Scripts são Bash de Termux** (`#!/data/data/com.termux/files/usr/bin/bash`).
  Mantenha compatibilidade POSIX/Termux; não introduza dependências que não existem
  no Termux sem instalar via `pkg`/`pip`. Pacotes Python do HA são instalados no
  venv **dentro do Ubuntu** (`proot-distro login ubuntu -- ~/hass-venv/bin/pip ...`).
- **WOL só funciona na mesma sub-rede** (broadcast UDP não atravessa VLAN/sub-rede sem
  IP Helper no roteador) e só com o PC em soft-off (S5) com energia em standby.
- **Ações destrutivas** (recriar o container Ubuntu, apagar `hass-config`, resetar HA)
  exigem confirmação explícita do usuário. Prefira alternativas não-destrutivas.
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
