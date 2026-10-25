# VaultKit

Global menu for **snippets + daily capture** for Obsidian on Linux desktops (EndeavourOS / Arch), powered by **Rofi** (GUI) and **fzf** (terminal). It combines the projects `mdsnip` (snippet/note/block manager) and `sendlog` (quick capture in the daily note) — it edits Markdown directly without requiring Obsidian or Templater to be open.

## Features

**Snippets** (based on mdsnip)
- Folder navigation in Rofi; copy to clipboard or type (`xdotool`)
- History and favorites; tag search (Obsidian-compatible)
- Extraction/indexing of code blocks from the vault; advanced terminal search (`fzf` + `glow`)
- Export/Import `.tar.gz`; snippet templates (`{{TITLE}}`, `{{DATE}}`, `{{CLIPBOARD}}`)

**Daily capture** (based on sendlog)
- **Quick capture**: 9 types with emojis (🧭 ✅ 🌱 💬 😴 💀 ⭐ 💩 ❓) inserted in the `# Capture` section of the daily note
- Tasks receive a checkbox: `- [ ] ✅ text - HH:mm \ [[AAAAMM-DD]]`
- **Open daily note**: `obsidian://` URI; creates the note if it does not exist — rendering the template offline (without Obsidian or Templater): mood, date/week, prev/next links and the daily quote (ZenQuotes API; empty if offline), including the vault's real Templater template (`<%* %>`, `tp.date.*`, `tp.web.daily_quote()`); unknown expressions are discarded

## Usage

```bash
vaultkit          # main menu (rofi)
vaultkit search   # note/block search in the terminal (fzf)
vaultkit log      # quick capture directly in today's daily note
vaultkit daily    # open today's daily note in Obsidian
vaultkit settings # settings menu
```

Main menu: Browse snippets · Quick capture · History · Favorites · Search by tag · Search in terminal · Open daily note · Settings.

## Installation

Requires EndeavourOS / Arch Linux (`pacman`).

```bash
./install.sh                                  # installs to /usr/local/bin
INSTALL_PREFIX="$HOME/.local" ./install.sh    # installs to ~/.local/bin (without sudo)
```

The installer installs dependencies, copies the Rofi theme, creates the symlink, and asks for the paths (snippets, vault, daily notes) one by one — pressing Enter accepts the defaults. Non-interactive mode:

```bash
VAULTKIT_VAULT_DIR="$HOME/Documentos/Notes" \
VAULTKIT_SNIPPETS_DIR="$HOME/Documentos/Notes/Snippets" \
VAULTKIT_DAILY_NOTES_DIR="$HOME/Documentos/Notes/Calendar & Review/Daily Notes" \
./install.sh
```

**Migration**: if `~/.config/mdsnip` exists (config/data/cache), it is copied to the new VaultKit prefix during updates. If `~/.config/sendlog` exists, the daily note keys and `daily-note-template.md` are migrated. Old files are preserved.

## Dependencies

`rofi`, `ripgrep`, `fzf`, `gawk`, `libnotify`, `tar`, `mousepad`, `glow`, `xdg-utils`, `xclip`, `xdotool`, `wl-clipboard` + a terminal emulator. Restrictions: Bash 4+.

## Configuration

Created automatically on first use (`~/.config/vaultkit/config`), and also editable from the Settings menu:

| Key | Default | Description |
|---|---|---|
| `VAULT_DIR` | `~/Documentos/Notes` | Vault (notes + code blocks) |
| `SNIPPETS_DIR` | `$VAULT_DIR/Snippets` | Snippets folder |
| `DAILY_NOTES_DIR` | `Calendar & Review/Daily Notes` (relative to the vault) | Daily notes |
| `OBSIDIAN_VAULT_NAME` | basename of `VAULT_DIR` | Vault name in Obsidian |
| `DAILY_NOTE_TEMPLATE` | template real do vault (ex.: `X/Templates/Format/B-Daily Note Template.md`), relativo ao vault | Template used when creating the daily note offline. Templater syntax is rendered by vaultkit itself (mood, `tp.date.*`, `tp.web.daily_quote()`, discarded unknown expressions); if the configured template is missing, falls back to `~/.local/share/vaultkit/templates/daily-note.md` (placeholders `{{DATE}}`, `{{TIME}}`, `{{PREVIOUS_DATE}}`, `{{NEXT_DATE}}`, `{{WEEK}}`, `{{MOOD}}`, `{{DAILY_QUOTE}}`) |
| `EDITOR_APP` / `TERMINAL_APP` | `mousepad` / detected | Apps used |
| `ROFI_WINDOW_WIDTH` | `510px` | Width of the Rofi window |

State under `~/.local/share/vaultkit/` (history/favorites) and cache under `~/.cache/vaultkit/`.

## Architecture

```
vaultkit.sh                 entry: menu + subcommands
lib/util.sh                 notify, url_encode
lib/config.sh               unified XDG config + path helpers
lib/snippet-core.sh         snippet core (clipboard, index, tags, export)
lib/rofi.sh                 rofi menu + theme
lib/ui-rofi.sh              Rofi menus for snippets + Settings
lib/daily-note.sh           quick capture + daily note (daily_*)
lib/note-search.sh          terminal fzf search (search_notes / nf)
assets/simple-tokyonight.rasi  Rofi theme
```

Origin: a merge of `~/Projetos/mdsnip` and `~/Projetos/obsidian-global-quick-capture` (SendLog), which have become legacy — the old `mdsnip` and `sendlog` commands are removed from PATH during updates.
# Obsidian-vaultkit-for-Linux
