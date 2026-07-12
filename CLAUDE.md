# CLAUDE.md

Este projeto usa **[AGENTS.md](AGENTS.md) como fonte de verdade única**. Leia-o
inteiro antes de qualquer mudança — ele descreve os scripts, a integração com o
Jarvis, os bugs conhecidos e o roadmap.

## Resumo de 30 segundos

- **Este repo:** scripts (Termux + udocker) para rodar Home Assistant num Android,
  a caminho de integrar com o Jarvis.
- **Código do Jarvis:** repositório **separado** em `D:\Jarvis-NIKO\JarvisServer`
  (já disponível como working directory nesta sessão). A integração HA de verdade
  vive no agente Python: `Agent/tools/homeassistant_tool.py` e
  `Agent/plugins/platforms/homeassistant/`. Config via `HASS_URL` / `HASS_TOKEN`
  (**não** `HA_URL`/`HA_TOKEN`).
- **Objetivo:** Jarvis liga o PC via Wake-on-LAN nativo do HA
  (`ha_call_service(domain="wake_on_lan", service="send_magic_packet")`).

## Notas para o Claude Code

- Ao investigar a integração, **leia o código real do Jarvis** em
  `D:\Jarvis-NIKO\JarvisServer` antes de afirmar como ele funciona — há divergências
  entre os roteiros (`.md`) e o código/scripts (nomes de env var, método de instalação,
  caminhos de config). O [AGENTS.md](AGENTS.md) lista essas divergências; confirme
  antes de agir.
- **Não perca `./haconfig`** (dados reais do HA) ao mexer nos scripts.
- **Preserve as proteções de segurança** da integração (domínios bloqueados e validação
  de `entity_id`/`domain`/`service` em `homeassistant_tool.py`). Nunca ecoe tokens.
- Confirme antes de ações destrutivas (apagar containers/config, resetar o HA).
