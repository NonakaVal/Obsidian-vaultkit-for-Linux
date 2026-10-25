#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

source lib/util.sh
source lib/config.sh
source lib/rofi.sh
source lib/daily-note.sh

# Silencia notificações no teste
notify() { printf '[notify] %s\n' "$1"; }

load_config

# Hermeticidade: nada é gravado fora de $tmp — nem o repo, nem o vault real.
# O template real do vault é apenas LIDO (caminho de leitura da config do usuário).
real_vault_template="$VAULT_DIR/X/Templates/Format/B-Daily Note Template.md"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
VAULT_DIR="$tmp/vault"
DAILY_NOTES_DIR="$tmp/vault/notas"

fail() {
    printf 'FALHOU: %s\n' "$1" >&2
    exit 1
}

assert() { # assert <texto-fixado> <arquivo> <mensagem>
    grep -Fq "$1" "$2" || fail "$3"
}
assert_absent() {
    grep -qF "$1" "$2" && fail "$3" || true
}

# -----------------------------------------------------------------------------
# 1) Fallback {{...}}: template configurado inexistente -> usa TEMPLATE_FILE
# -----------------------------------------------------------------------------
DAILY_NOTE_TEMPLATE="$tmp/nao-existe.md"
daily_ensure_template
[[ -f "$TEMPLATE_FILE" ]] || fail 'TEMPLATE_FILE não foi criado pelo daily_ensure_template'

render_daily_template '😄 – Happy' '2026-10-25' '08:19' > "$tmp/fallback.md"
assert 'dateCreated: 2026-10-25 @ 08:19' "$tmp/fallback.md" 'fallback: dateCreated não resolvido'
assert "week: '[[2026 Week 43]]'" "$tmp/fallback.md" 'fallback: week não resolvido'
assert 'daily-mood: "😄 – Happy"' "$tmp/fallback.md" 'fallback: humor não inserido'
assert '[[2026-10-24|↶ Previous Day]]' "$tmp/fallback.md" 'fallback: dia anterior não resolvido'
assert '[[2026-10-26|Following Day ↷]]' "$tmp/fallback.md" 'fallback: dia seguinte não resolvido'
assert '# Capture' "$tmp/fallback.md" 'fallback: seção Capture ausente'
assert_absent '{{' "$tmp/fallback.md" 'fallback: placeholder restante'
assert_absent '<%' "$tmp/fallback.md" 'fallback: sintaxe Templater restante'

# -----------------------------------------------------------------------------
# 2) Template real do vault (sintaxe Templater), render offline
# -----------------------------------------------------------------------------
if [[ -f "$real_vault_template" ]]; then
    DAILY_NOTE_TEMPLATE="$real_vault_template"
    export DAILY_NOTE_TEMPLATE
    render_daily_template '😐 – Meh' '2026-10-25' '08:19' > "$tmp/vault.md"
    assert "week: '[[2026 Week 43]]'" "$tmp/vault.md" 'vault: week não resolvido (bug do literal [Week]?)'
    assert 'dateCreated: 2026-10-25 @ 08:19' "$tmp/vault.md" 'vault: dateCreated não resolvido'
    assert 'daily-mood: "😐 – Meh"' "$tmp/vault.md" 'vault: humor não inserido'
    assert '[[2026-10-24|↶ Previous Day]] | [[2026-10-26|Following Day ↷]]' "$tmp/vault.md" 'vault: navegação não resolvida'
    assert_absent '<%' "$tmp/vault.md" 'vault: sintaxe Templater restante'
    assert_absent 'tp.file.cursor' "$tmp/vault.md" 'vault: cursor não descartado'
    # Cota: vazia (offline) ou callout completo com autor
    if grep -q '> \[!quote\]' "$tmp/vault.md"; then
        grep -q '^> — ' "$tmp/vault.md" || fail 'vault: cota sem autor'
    fi
    echo 'cota do dia: presente/consistente'
fi

# -----------------------------------------------------------------------------
# 3) Fluxo completo add_log (stub do rofi), com criação da nota
# -----------------------------------------------------------------------------
# add_log chama rofi_menu via command substitution (subshell): estado do stub
# precisa viver em arquivo, não em variável do processo.
ROFI_QUEUE="$tmp/rofi-queue"
printf '%s\n' '🧭 Intenção' 'fluxo completo vaultkit offline' '😄 – Happy' > "$ROFI_QUEUE"
rofi_menu() {
    [[ -s "$ROFI_QUEUE" ]] || return 1
    local a
    a="$(head -n1 "$ROFI_QUEUE")"
    [[ -z "$a" ]] && return 1
    sed -i '1d' "$ROFI_QUEUE"
    printf '%s\n' "$a"
}

add_log || fail 'add_log retornou erro'
note="$DAILY_NOTES_DIR/2026-10-25.md"
[[ -f "$note" ]] || fail 'add_log não criou a nota diária'
assert 'daily-mood: "😄 – Happy"' "$note" 'add_log: nota criada sem humor'
assert "week: '[[2026 Week 43]]'" "$note" 'add_log: week incorreto na nota criada'
assert '🧭 fluxo completo vaultkit offline - ' "$note" 'add_log: capture não inserido'

# ---------------------------------------------------------------------------
printf 'vaultkit render/capture offline: OK (hermético em %s)\n' "$tmp"
