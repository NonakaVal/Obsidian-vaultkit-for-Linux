# VaultKit

Menu global **snippets + captura diária** para o Obsidian no desktop Linux (EndeavourOS / Arch), via **Rofi** (GUI) e **fzf** (terminal). União dos projetos `mdsnip` (gerenciador de snippets/notas/blocos) e `sendlog` (quick capture na nota diária) — altera o Markdown diretamente, sem depender do Obsidian ou do Templater estarem abertos.

## Funcionalidades

**Snippets** (base mdsnip)
- Navegação por pastas no Rofi; copiar para clipboard ou digitar (`xdotool`)
- Histórico e favoritos; busca por tag (compatível Obsidian)
- Extração/índice de blocos de código da vault; busca avançada no terminal (`fzf` + `glow`)
- Export/Import `.tar.gz`; templates de snippet (`{{TITLE}}`, `{{DATE}}`, `{{CLIPBOARD}}`)

**Captura diária** (base sendlog)
- **Captura rápida**: 9 tipos com emojis (🧭 ✅ 🌱 💬 😴 💀 ⭐ 💩 ❓) inseridos na seção `# Capture` da nota diária
- Tarefa ganha checkbox: `- [ ] ✅ texto - HH:mm \ [[AAAAMM-DD]]`
- **Abrir nota diária**: URI `obsidian://`; cria a nota (com humor, links prev/next, `Capture/Events/Caderno`) se não existir

## Uso

```bash
vaultkit          # menu principal (rofi)
vaultkit search   # busca de notas/blocos no terminal (fzf)
vaultkit log      # captura rápida direto na nota diária de hoje
vaultkit daily    # abre a nota diária de hoje no Obsidian
vaultkit settings # menu de configurações
```

Menu principal: Navegar snippets · Captura rápida · Histórico · Favoritos · Buscar por tag · Buscar no terminal · Abrir nota diária · Configurações.

## Instalação

Requer EndeavourOS / Arch Linux (`pacman`).

```bash
./install.sh                                  # instala em /usr/local/bin
INSTALL_PREFIX="$HOME/.local" ./install.sh    # instala em ~/.local/bin (sem sudo)
```

O instalador instala dependências, copia o tema Rofi, cria o symlink e pergunta os caminhos (snippets, vault, notas diárias), um por vez — Enter aceita os padrões. Modo não interativo:

```bash
VAULTKIT_VAULT_DIR="$HOME/Documentos/Notes" \
VAULTKIT_SNIPPETS_DIR="$HOME/Documentos/Notes/Snippets" \
VAULTKIT_DAILY_NOTES_DIR="$HOME/Documentos/Notes/Calendar & Review/Daily Notes" \
./install.sh
```

**Migração**: se existir `~/.config/mdsnip` (config/data/cache), é copiado para o novo prefixo do VaultKit na atualização. Se existir `~/.config/sendlog`, as chaves da nota diária e o `daily-note-template.md` são migrados. Os arquivos antigos são preservados.

## Dependências

`rofi`, `ripgrep`, `fzf`, `gawk`, `libnotify`, `tar`, `mousepad`, `glow`, `xdg-utils`, `xclip`, `xdotool`, `wl-clipboard` + um terminal emulador. Restrições: Bash 4+.

## Configuração

Criada automaticamente no primeiro uso (`~/.config/vaultkit/config`), também editável pelo menu Configuracoes:

| Chave | Padrão | Descrição |
|---|---|---|
| `VAULT_DIR` | `~/Documentos/Notes` | Vault (notas + code blocks) |
| `SNIPPETS_DIR` | `$VAULT_DIR/Snippets` | Pasta de snippets |
| `DAILY_NOTES_DIR` | `Calendar & Review/Daily Notes` (relativo ao vault) | Notas diárias |
| `OBSIDIAN_VAULT_NAME` | basename de `VAULT_DIR` | Nome da vault no Obsidian |
| `DAILY_NOTE_TEMPLATE` | `config/templates/daily-note.md` | Template da nota diária (placeholders `{{DATE}}`, `{{TIME}}`, `{{PREVIOUS_DATE}}`, `{{NEXT_DATE}}`, `{{WEEK}}`, `{{MOOD}}`, `{{DAILY_QUOTE}}`) |
| `EDITOR_APP` / `TERMINAL_APP` | `mousepad` / detectado | Apps de uso |
| `ROFI_WINDOW_WIDTH` | `510px` | Largura da janela do Rofi |

Estados em `~/.local/share/vaultkit/` (histórico/favoritos) e cache em `~/.cache/vaultkit/`.

## Arquitetura

```
vaultkit.sh                 entry: menu + subcomandos
lib/util.sh                 notify, url_encode
lib/config.sh               config XDG unificado + helpers de caminho
lib/snippet-core.sh         núcleo de snippets (clipboard, índice, tags, export)
lib/rofi.sh                 rofi_menu + tema
lib/ui-rofi.sh              menus Rofi dos snippets + Configuracoes
lib/daily-note.sh           captura rápida + nota diária (daily_*)
lib/note-search.sh          busca fzf no terminal (search_notes / nf)
assets/simple-tokyonight.rasi  tema Rofi
```

Origem: fusão de `~/Projetos/mdsnip` e `~/Projetos/obsidian-global-quick-capture` (SendLog), que se tornam legados — comandos antigos `mdsnip` e `sendlog` são removidos do PATH na atualização.
# Obsidian-vaultkit-for-Linux
