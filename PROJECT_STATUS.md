# PROJECT_STATUS.md — Estado do projeto HomeAssistent

> Documento vivo. Atualizado ao final de cada sessão de trabalho.
> **Qualquer IA que iniciar uma sessão neste projeto DEVE ler este arquivo primeiro.**

---

## Última atualização
2026-07-12 — sessão: correção docs udocker→proot-distro, scripts reais puxados do celular, HACS instalado.

---

## O que é este projeto

Home Assistant Core rodando em um celular Android antigo via **Termux + proot-distro
Ubuntu** (venv Python), integrado ao assistente pessoal Jarvis (repo separado em
`D:\Jarvis-NIKO\JarvisServer`).

**Objetivo final:** Jarvis liga o PC via Wake-on-LAN nativo do HA, sem ESP32 como
intermediário.

---

## Acesso ao celular (IMPORTANTE — leia antes de qualquer tarefa)

O agente tem acesso SSH direto ao Termux do celular. **Execute comandos sem pedir
para o usuário fazê-los manualmente.**

| Parâmetro | Valor |
|---|---|
| Host | `192.168.0.4` |
| Porta | `8022` |
| Usuário | `u0_a258` |
| Chave | `C:\Users\Uanderson\.ssh\id_termux` |
| MCP | `ssh-mcp` (registrado no Claude Code, escopo do projeto) |

Se SSH falhar → sshd parou. Peça ao usuário rodar `sshd` no Termux.

**Rodar comando dentro do Ubuntu (onde vive o HA):**
`proot-distro login ubuntu -- <comando>`
**Start/stop do HA:** `bash ~/start-homeassistant.sh` / `bash ~/stop-homeassistant.sh`

---

## Método de instalação real (CONFIRMADO 2026-07-12)

**proot-distro Ubuntu + venv Python — NÃO udocker.** A documentação antiga assumia
udocker; ao inspecionar o celular via SSH, o que roda de fato é:

| Item | Valor real no celular |
|---|---|
| Runtime | `proot-distro` (container Ubuntu, sem root) |
| Binário HA | `~/hass-venv/bin/hass` |
| Config/dados | `~/hass-config/` (usuário, onboarding, dispositivos, HACS) |
| Start | `proot-distro login ubuntu -- ~/hass-venv/bin/hass -c ~/hass-config` |
| Porta | `8123` (config fixa `http: server_host: 0.0.0.0`) |

Os scripts udocker foram movidos para `legacy-udocker/` (referência histórica, não
rodam). Scripts reais estão na raiz: `setup-homeassistant.sh`, `start-homeassistant.sh`,
`stop-homeassistant.sh`, `install-hacs.sh`.

---

## O que já foi feito ✅

- [x] SSH configurado no Termux (porta 8022, sshd via `sv-enable sshd`)
- [x] Chave SSH gerada no PC (`C:\Users\Uanderson\.ssh\id_termux`)
- [x] MCP `ssh-mcp` registrado no Claude Code
- [x] HA rodando via proot-distro Ubuntu, dados em `~/hass-config/`
- [x] Sistema de memória criado (`memory/`, `PROJECT_STATUS.md`, regras no CLAUDE.md/AGENTS.md)
- [x] **HACS instalado** em `~/hass-config/custom_components/hacs/` (release mais recente, com HA parado)
- [x] Repo sincronizado com a realidade: scripts proot puxados do celular; scripts
      udocker movidos p/ `legacy-udocker/`; desktop Linux p/ `termux-desktop/`
- [x] Docs (`AGENTS.md`, `PROJECT_STATUS.md`) reescritas para proot-distro

---

## O que falta fazer 🔲

### Fase 1 — Infraestrutura (quase concluída)
- [ ] Reiniciar o HA (`bash ~/start-homeassistant.sh`) e **verificar HACS na UI**
      (Configurações → Dispositivos e Serviços → HACS deve aparecer)
- [ ] Investigar log gigante: `~/hass-config/home-assistant.log` estava com **~182 MB**
      (algo está spammando). Ver o que se repete antes de truncar.
- [ ] Confirmar `ssh-mcp` aparecendo no `claude mcp list` (registrado em escopo de
      projeto; SSH direto funciona, mas o MCP não listou nesta sessão)

### Fase 2 — Wake-on-LAN nativo
- [ ] Anotar o MAC address da placa de rede do PC
- [ ] Habilitar Wake-on-LAN no BIOS/UEFI do PC
- [ ] Habilitar WOL no Windows (Gerenciador de Dispositivos → adaptador de rede)
- [ ] Adicionar integração "Wake on LAN" no HA (via UI ou `configuration.yaml`)
- [ ] Testar manualmente: botão no HA → PC liga
- [ ] Integrar no Jarvis via `ha_call_service(domain="wake_on_lan", service="send_magic_packet")`

### Fase 3 — WireGuard (acesso remoto)
- [ ] Configurar WireGuard no celular (cliente) → VPS Oracle (servidor)
- [ ] Configurar `HASS_URL` e `HASS_TOKEN` no Jarvis apontando para IP WireGuard
- [ ] Testar Jarvis controlando HA remotamente

---

## O que falta testar 🧪

- [ ] HACS visível e funcional na UI do HA (após restart)
- [ ] SSH ao Termux após reinicialização do celular (sshd sobe sozinho?)
- [ ] HA sobe automaticamente após reboot do celular (termux-boot configurado?)
- [ ] Wake-on-LAN pelo botão da UI do HA
- [ ] Wake-on-LAN chamado pelo Jarvis remotamente

---

## Bugs conhecidos 🐛

| Bug | Status | Fix |
|---|---|---|
| Onboarding travado em "Analytics" | ✅ Resolvido | Onboarding já concluído no celular |
| Zeroconf/SSDP: `No adapter found for IP address fe80::` | Contornado | `setup-homeassistant.sh` patcheia `ifaddr/_posix.py`; ainda assim adicionar integrações manualmente por IP |
| `home-assistant.log` ~182 MB | 🔲 Investigar | Ver o que spamma antes de truncar; considerar limitar logger |
| Termux morto pelo Android em alguns fabricantes | Monitorar | Desativar otimização de bateria; usar `termux-boot` |

---

## Arquitetura atual

```
[PC Windows]
  ├── Claude Code (MCP ssh-mcp) ──SSH:8022──► [Celular Android]
  └── Jarvis (D:\Jarvis-NIKO\JarvisServer)          └── Termux
                                                         ├── sshd (porta 8022)
                                                         └── proot-distro → Ubuntu
                                                             └── venv ~/hass-venv
                                                                 └── hass -c ~/hass-config (porta 8123)
                                                                     └── custom_components/hacs/
```

Componentes complementares (Matter 5580, Music 8095, Wyoming 10400) rodariam como
processos irmãos no mesmo Android; proot não isola rede, então HA os alcança por
`localhost:PORTA` (mesma razão pela qual o WOL nativo alcança a LAN).

---

## Decisões importantes

- **proot-distro (NÃO udocker):** confirmado inspecionando o celular. udocker era o
  plano original (scripts em `legacy-udocker/`), mas o que funcionou e está no ar é
  proot-distro Ubuntu + venv. Decisão do usuário em 2026-07-12: padronizar em proot.
- **Config do HA:** `~/hass-config/` — NUNCA apagar. Contém usuário, dispositivos, HACS.
- **Variáveis Jarvis:** `HASS_URL` e `HASS_TOKEN` (não `HA_URL`/`HA_TOKEN`).
- **WOL só funciona na mesma sub-rede** — celular e PC precisam estar no mesmo Wi-Fi.
- **Git:** o repositório (remote `brevMidias/H.A.brev`) vive só no PC; o celular tem
  os scripts soltos, sem `.git`. Sincronização de código é PC→GitHub, não pelo celular.

---

## Próxima sessão — comece por aqui

1. Ler este arquivo
2. Verificar se SSH ainda está ativo: `ssh ... u0_a258@192.168.0.4 whoami`
3. Reiniciar o HA e verificar o HACS na UI (primeira tarefa pendente da Fase 1)
