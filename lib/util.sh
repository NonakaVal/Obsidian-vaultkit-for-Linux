#!/bin/bash

# =============================================================================
# util.sh — Utilitários compartilhados (notify, url_encode)
# Base: sendlog (obsidian-global-quick-capture)
# =============================================================================

# Notificação desktop com label do app; fallback para stderr sem notify-send
notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "vaultkit" "$1" 2>/dev/null || printf 'vaultkit: %s\n' "$1" >&2
    else
        printf 'vaultkit: %s\n' "$1" >&2
    fi
}

# Percent-encode para URIs (obsidian://, file://)
url_encode() {
    local input="$1" output="" char hex i
    local LC_ALL=C
    for ((i = 0; i < ${#input}; i++)); do
        char="${input:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) output+="$char" ;;
            *) printf -v hex '%%%02X' "'$char"; output+="$hex" ;;
        esac
    done
    printf '%s' "$output"
}
