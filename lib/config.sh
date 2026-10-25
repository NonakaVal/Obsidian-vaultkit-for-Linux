#!/bin/bash

# =============================================================================
# config.sh — Configuração centralizada do vaultkit
# XDG-compliant: ~/.config/vaultkit/config
# =============================================================================

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vaultkit"
CONFIG_FILE="$CONFIG_DIR/config"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/vaultkit"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vaultkit"
TEMPLATE_DIR="$CONFIG_DIR/templates"

# TEMPLATE_FILE = template de fallback da note diária (usado quando o template
# configurado — ex.: o real do vault — não está disponível). Vive em DATA_DIR,
# FORA de TEMPLATE_DIR: este é o catálogo de templates de snippet mostrado ao
# criar um snippet, e o template diário não é um snippet.
TEMPLATE_FILE="$DATA_DIR/templates/daily-note.md"

HISTORY_FILE="$DATA_DIR/history"
FAVORITES_FILE="$DATA_DIR/favorites"

DATE_FORMAT="$(date +%Y-%m-%d)"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    # Snippets
    VAULT_DIR="${VAULT_DIR:-$HOME/Documentos/Notes}"
    VAULT_DIR="$(expand_path "$VAULT_DIR")"
    VAULT_DIR="$(normalize_path "$VAULT_DIR" "$HOME")"
    SNIPPETS_DIR="${SNIPPETS_DIR:-$VAULT_DIR/Snippets}"
    EDITOR_APP="${EDITOR_APP:-mousepad}"
    TERMINAL_APP="${TERMINAL_APP:-$(detect_terminal)}"
    DEFAULT_SORT="${DEFAULT_SORT:-recent}"
    HISTORY_LIMIT="${HISTORY_LIMIT:-40}"
    PREVIEW_LINES="${PREVIEW_LINES:-5}"
    CACHE_TTL="${CACHE_TTL:-30}"
    ROFI_WINDOW_WIDTH="${ROFI_WINDOW_WIDTH:-510px}"

    # Daily Note (SendLog)
    DAILY_NOTES_DIR="${DAILY_NOTES_DIR:-Calendar & Review/Daily Notes}"   # relativo ao VAULT_DIR
    OBSIDIAN_VAULT_NAME="${OBSIDIAN_VAULT_NAME:-$(basename "$VAULT_DIR")}"
    DAILY_NOTE_TEMPLATE="${DAILY_NOTE_TEMPLATE:-X/Templates/Format/B-Daily Note Template.md}"
    DAILY_NOTE_TEMPLATE="$(normalize_path "$DAILY_NOTE_TEMPLATE" "$VAULT_DIR")"

    # Propagate para core.sh / note-search.sh / daily-note.sh
    export VAULT_DIR SNIPPETS_DIR EDITOR_APP TERMINAL_APP ROFI_WINDOW_WIDTH \
        DAILY_NOTES_DIR OBSIDIAN_VAULT_NAME DAILY_NOTE_TEMPLATE
}

# Detecta um terminal disponível (fallback quando TERMINAL_APP não está no config)
detect_terminal() {
    local t
    for t in konsole kitty alacritty wezterm foot ghostty gnome-terminal xterm; do
        if command -v "$t" >/dev/null 2>&1; then
            echo "$t"
            return 0
        fi
    done
    echo "xterm"
}

ensure_dirs() {
    mkdir -p "$VAULT_DIR" "$SNIPPETS_DIR" "$DATA_DIR" "$CACHE_DIR" "$CONFIG_DIR" "$TEMPLATE_DIR"
    touch "$HISTORY_FILE" "$FAVORITES_FILE" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Helpers de caminho (base: SendLog)
# -----------------------------------------------------------------------------

expand_path() {
    local path="$1"
    path="${path//\$\{HOME\}/$HOME}"
    path="${path//\$HOME/$HOME}"
    case "$path" in
        "~") path="$HOME" ;;
        "~/"*) path="$HOME/${path:2}" ;;
    esac
    printf '%s' "$path"
}

normalize_path() {
    local path base
    path="$(expand_path "$1")"
    base="$2"
    [[ "$path" == /* ]] || path="$base/$path"
    printf '%s' "$path"
}

# Resolve DAILY_NOTES_DIR (pode ser relativo ao vault) para caminho absoluto
daily_notes_path() {
    local dir
    dir="$(expand_path "$DAILY_NOTES_DIR")"
    if [[ "$dir" != /* ]]; then
        dir="$VAULT_DIR/$dir"
    fi
    printf '%s' "$dir"
}

_config_quote() {
    local value="$1" quoted="" char i
    for ((i = 0; i < ${#value}; i++)); do
        char="${value:i:1}"
        if [[ "$char" == $'\\' || "$char" == '"' || "$char" == '$' || "$char" == '`' ]]; then
            quoted+="\\$char"
        else
            quoted+="$char"
        fi
    done
    printf '"%s"' "$quoted"
}

write_default_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR"
        {
            printf '# vaultkit — configuração\n'
            printf '# Pastas de busca / exemplos\n'
            printf 'VAULT_DIR=%s\n' "$(_config_quote "$HOME/Documentos/Notes")"
            printf 'SNIPPETS_DIR=%s\n' "$(_config_quote "$HOME/Documentos/Notes/Snippets")"
            printf '# Daily Note (relativo ao VAULT_DIR se relativo)\n'
            printf 'DAILY_NOTES_DIR=%s\n' "$(_config_quote "Calendar & Review/Daily Notes")"
            printf 'OBSIDIAN_VAULT_NAME=%s   # nome da vault no Obsidian (padrão: última pasta de VAULT_DIR)\n' "$(_config_quote "$(basename "$HOME/Documentos/Notes")")"
            printf 'DAILY_NOTE_TEMPLATE=%s   # template da note diária (relativo ao vault; fallback: ~/.local/share/vaultkit/templates/daily-note.md)\n' "$(_config_quote "X/Templates/Format/B-Daily Note Template.md")"
            printf '# Aplicativos\n'
            printf 'EDITOR_APP=%s\n' "$(_config_quote "mousepad")"
            printf 'TERMINAL_APP=%s   # terminal aberto pela busca (Buscar no terminal)\n' "$(_config_quote "$(detect_terminal)")"
            printf '# Uso padrão\n'
            printf 'DEFAULT_SORT=%s\n' "$(_config_quote "recent")"
            printf 'HISTORY_LIMIT=%s\n' "$(_config_quote "40")"
            printf 'PREVIEW_LINES=%s\n' "$(_config_quote "5")"
            printf 'CACHE_TTL=%s\n' "$(_config_quote "30")"
            printf '# Interface\n'
            printf 'ROFI_WINDOW_WIDTH=%s   # largura da janela rofi (ex.: 510px)\n' "$(_config_quote "510px")"
        } > "$CONFIG_FILE"
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    {
        printf '# vaultkit — configuração\n'
        printf '# Pastas de busca / exemplos\n'
        printf 'VAULT_DIR=%s\n' "$(_config_quote "$VAULT_DIR")"
        printf 'SNIPPETS_DIR=%s\n' "$(_config_quote "$SNIPPETS_DIR")"
        printf '# Daily Note\n'
        printf 'DAILY_NOTES_DIR=%s\n' "$(_config_quote "$DAILY_NOTES_DIR")"
        printf 'OBSIDIAN_VAULT_NAME=%s\n' "$(_config_quote "$OBSIDIAN_VAULT_NAME")"
        printf 'DAILY_NOTE_TEMPLATE=%s\n' "$(_config_quote "$DAILY_NOTE_TEMPLATE")"
        printf '# Aplicativos\n'
        printf 'EDITOR_APP=%s\n' "$(_config_quote "$EDITOR_APP")"
        printf 'TERMINAL_APP=%s   # terminal aberto pela busca (Buscar no terminal)\n' "$(_config_quote "$TERMINAL_APP")"
        printf '# Uso padrão\n'
        printf 'DEFAULT_SORT=%s\n' "$(_config_quote "$DEFAULT_SORT")"
        printf 'HISTORY_LIMIT=%s\n' "$(_config_quote "$HISTORY_LIMIT")"
        printf 'PREVIEW_LINES=%s\n' "$(_config_quote "$PREVIEW_LINES")"
        printf 'CACHE_TTL=%s\n' "$(_config_quote "$CACHE_TTL")"
        printf '# Interface\n'
        printf 'ROFI_WINDOW_WIDTH=%s   # largura da janela rofi (ex.: 510px)\n' "$(_config_quote "$ROFI_WINDOW_WIDTH")"
    } > "$CONFIG_FILE"
}
