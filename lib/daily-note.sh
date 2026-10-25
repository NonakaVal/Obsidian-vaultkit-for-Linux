#!/usr/bin/env bash

LOG_TYPES=(
    "🧭 Intenção"
    "✅ Nova Tarefa"
    "🌱 Motivação"
    "💬 Gratidão"
    "😴 Even"
    "💀 Puts"
    "⭐ Algo bom"
    "💩 Cagada"
    "❓ wtf?"
)

log_emoji() {
    case "$1" in
        "🧭 Intenção") printf '🧭' ;;
        "✅ Nova Tarefa") printf '✅' ;;
        "🌱 Motivação") printf '🌱' ;;
        "💬 Gratidão") printf '💬' ;;
        "😴 Even") printf '😴' ;;
        "💀 Puts") printf '💀' ;;
        "⭐ Algo bom") printf '⭐' ;;
        "💩 Cagada") printf '💩' ;;
        "❓ wtf?") printf '❓' ;;
        *) return 1 ;;
    esac
}

today_date() {
    date '+%Y-%m-%d'
}

daily_note_file() {
    printf '%s/%s.md' "$(daily_notes_path)" "$(today_date)"
}

choose_mood() {
    local moods choice
    moods="$(printf '🙂 – Neutral\n😄 – Happy\n😐 – Meh\n😞 – Sad\n😠 – Frustrated\nDigitar humor personalizado')"
    choice="$(printf '%s\n' "$moods" | rofi_menu -p 'Humor do dia')" || return 1
    [[ -z "$choice" ]] && return 1

    if [[ "$choice" == "Digitar humor personalizado" ]]; then
        choice="$(rofi_menu -p 'Humor personalizado')" || return 1
    fi
    [[ -n "$choice" ]] || return 1
    printf '%s' "$choice"
}

fetch_daily_quote() {
    local payload quote author
    payload="$(curl -fsS -m 4 'https://zenquotes.io/api/random' 2>/dev/null)" || return 0
    quote="$(jq -r '.[0].q // empty' <<<"$payload")" || return 0
    author="$(jq -r '.[0].a // empty' <<<"$payload")" || return 0
    [[ -n "$quote" && -n "$author" ]] || return 0
    printf '> [!quote] %s\n> — %s' "$quote" "$author"
}

# Converte a sintaxe de template do Templater usada no vault no momento em que a
# nota é criada, sem Obsidian nem Templater:
#   - blocos de execução `<%* ... -%>`/`<%* ... %>` são descartados (o humor já
#     foi pedido ao usuário pelo rofi e entra via SENDLOG_MOOD);
#   - `<% tp.date.now/yesterday/tomorrow("FMT") %>` são resolvidos via date(1);
#   - `<% selectedMood %>` recebe o humor informado;
#   - `<% tp.web.daily_quote() %>` recebe a cota buscada pelo sendlog;
#   - `tp.file.cursor()` e qualquer expressão desconhecida são descartados.
render_templater_syntax() {
    SENDLOG_MOOD="$1" SENDLOG_DATE="$2" SENDLOG_TIME="$3" \
    SENDLOG_YESTERDAY="$4" SENDLOG_TOMORROW="$5" SENDLOG_QUOTE="$6" \
    awk '
        function extract_format(expr,   fmt, q, rest) {
            q = index(expr, "\"")
            if (!q) return ""
            rest = substr(expr, q + 1)
            fmt = substr(rest, 1, index(rest, "\"") - 1)
            return fmt
        }

        # Tokens de formato do Moment/Templater -> strftime
        function to_date_fmt(fmt,   s, i, n) {
            s = ""; i = 1; n = length(fmt)
            while (i <= n) {
                if (substr(fmt, i, 1) == "[") {
                    j = i + 1
                    while (j <= n && substr(fmt, j, 1) != "]") j++
                    if (j > n) { s = s substr(fmt, i); break }
                    s = s substr(fmt, i + 1, j - i - 1)
                    i = j + 1
                } else if (substr(fmt, i, 4) == "YYYY") { s = s "%Y"; i += 4 }
                else if (substr(fmt, i, 2) == "YY") { s = s "%y"; i += 2 }
                else if (substr(fmt, i, 2) == "MM") { s = s "%m"; i += 2 }
                else if (substr(fmt, i, 2) == "DD") { s = s "%d"; i += 2 }
                else if (substr(fmt, i, 2) == "HH") { s = s "%H"; i += 2 }
                else if (substr(fmt, i, 2) == "mm") { s = s "%M"; i += 2 }
                else if (substr(fmt, i, 2) == "ss") { s = s "%S"; i += 2 }
                else if (substr(fmt, i, 2) == "WW") { s = s "%V"; i += 2 }
                else { s = s substr(fmt, i, 1); i++ }
            }
            return s
        }

        function resolve_date(base, sfmt,   cmd, line) {
            cmd = "date --date=\"" base "\" +\"" sfmt "\""
            cmd | getline line
            close(cmd)
            return line
        }

        { content = content $0 "\n" }
        END {
            mood = ENVIRON["SENDLOG_MOOD"]
            dv = ENVIRON["SENDLOG_DATE"]; tv = ENVIRON["SENDLOG_TIME"]
            yd = ENVIRON["SENDLOG_YESTERDAY"]; tm = ENVIRON["SENDLOG_TOMORROW"]
            quote = ENVIRON["SENDLOG_QUOTE"]
            out = ""
            while ((cur = index(content, "<%")) > 0) {
                out = out substr(content, 1, cur - 1)
                content = substr(content, cur)
                if (substr(content, 1, 3) == "<%*") {
                    close_pos = index(content, "%>")
                    if (close_pos == 0) { content = ""; break }
                    closes_with_dash = (substr(content, close_pos - 1, 1) == "-")
                    content = substr(content, close_pos + 2)
                    if (closes_with_dash) { sub(/^[ \t]*\r?\n/, "", content) }
                } else {
                    close_pos = index(content, "%>")
                    if (close_pos == 0) { out = out content; content = ""; break }
                    expr = substr(content, 3, close_pos - 3)
                    content = substr(content, close_pos + 2)
                    if (expr ~ /tp\.web\.daily_quote/) {
                        out = out quote
                    } else if (expr ~ /selectedMood/) {
                        out = out mood
                    } else if (match(expr, /tp\.date\.(now|yesterday|tomorrow)/)) {
                        fn = substr(expr, RSTART + 8, RLENGTH - 8)
                        if (fn == "now") base = dv
                        else if (fn == "yesterday") base = yd
                        else base = tm
                        sfmt = to_date_fmt(extract_format(expr))
                        if (sfmt ~ /%H|%M|%S/) base = base " " tv
                        out = out resolve_date(base, sfmt)
                    }
                    # Expressão não reconhecida (como tp.file.cursor()) é descartada.
                }
            }
            printf "%s%s", out, content
        }
    '
}

render_daily_template() {
    local mood="$1" date_value="$2" time_value="$3"
    local template yesterday tomorrow quote rendered

    template="$DAILY_NOTE_TEMPLATE"
    if [[ ! -f "$template" ]]; then
        template="$TEMPLATE_FILE"
    fi
    [[ -f "$template" ]] || {
        notify "Template da nota diária não encontrado: $DAILY_NOTE_TEMPLATE"
        return 1
    }

    yesterday="$(date -d "$date_value -1 day" '+%Y-%m-%d')"
    tomorrow="$(date -d "$date_value +1 day" '+%Y-%m-%d')"
    quote="$(fetch_daily_quote)"
    rendered="$(render_templater_syntax "$mood" "$date_value" "$time_value" "$yesterday" "$tomorrow" "$quote" < "$template")" || {
        notify "Não foi possível processar o template da nota diária: $template"
        return 1
    }

    # Placeholders legados ({{VAR}}) para templates simples fora do vault
    rendered="${rendered//\{\{DATE\}\}/$date_value}"
    rendered="${rendered//\{\{TIME\}\}/$time_value}"
    rendered="${rendered//\{\{PREVIOUS_DATE\}\}/$yesterday}"
    rendered="${rendered//\{\{NEXT_DATE\}\}/$tomorrow}"
    rendered="${rendered//\{\{WEEK\}\}/$(date -d "$date_value" '+%G Week %V')}"
    rendered="${rendered//\{\{MOOD\}\}/$mood}"
    rendered="${rendered//\{\{DAILY_QUOTE\}\}/$quote}"
    printf '%s\n' "$rendered"
}

create_daily_note() {
    local file="$1" mood="$2" dir date_value time_value rendered
    dir="$(dirname "$file")"
    date_value="$(today_date)"
    time_value="$(date '+%H:%M')"

    mkdir -p "$dir"
    rendered="$(render_daily_template "$mood" "$date_value" "$time_value")"
    (umask 077; set -o noclobber; printf '%s' "$rendered" > "$file") 2>/dev/null || {
        [[ -f "$file" ]] && return 0
        notify "Não foi possível criar a nota diária: $file"
        return 1
    }
}

append_capture_log() {
    local file="$1" line="$2" temp
    [[ -f "$file" ]] || return 1
    temp="$(mktemp "${file}.sendlog.XXXXXX")" || return 1

    if ! SENDLOG_ENTRY="$line" awk -v header='# Capture' '
        {
            lines[NR] = $0
            if (!section && $0 ~ /^[[:space:]]*#[[:space:]]+Capture[[:space:]]*$/) section = NR
        }
        END {
            if (!section) {
                for (i = 1; i <= NR; i++) print lines[i]
                if (NR && lines[NR] != "") print ""
                print header
                print ENVIRON["SENDLOG_ENTRY"]
                exit
            }

            end = NR + 1
            for (i = section + 1; i <= NR; i++) {
                if (lines[i] ~ /^#+[[:space:]]/) {
                    end = i
                    break
                }
            }

            insert = end - 1
            while (insert > section && lines[insert] ~ /^[[:space:]]*$/) insert--
            if (insert < section) insert = section

            for (i = 1; i <= NR; i++) {
                print lines[i]
                if (i == insert) print ENVIRON["SENDLOG_ENTRY"]
            }
        }
    ' "$file" > "$temp"; then
        rm -f -- "$temp"
        notify "Não foi possível atualizar a nota diária: $file"
        return 1
    fi

    chmod --reference="$file" "$temp" 2>/dev/null || true
    mv -- "$temp" "$file" || {
        rm -f -- "$temp"
        notify "Não foi possível gravar a nota diária: $file"
        return 1
    }
}

add_log() {
    local selected emoji value date_value time_value line file mood
    selected="$(printf '%s\n' "${LOG_TYPES[@]}" | rofi_menu -p 'Que tipo de capture?')" || return 0
    [[ -n "$selected" ]] || return 0
    emoji="$(log_emoji "$selected")" || return 0

    value="$(rofi_menu -p "$emoji ...")" || return 0
    value="${value//$'\n'/ }"
    value="${value//$'\r'/}"
    [[ -n "${value//[[:space:]]/}" ]] || return 0

    file="$(daily_note_file)"
    if [[ ! -f "$file" ]]; then
        mood="$(choose_mood)" || return 0
        create_daily_note "$file" "$mood" || return 1
    fi

    date_value="$(today_date)"
    time_value="$(date '+%H:%M')"
    if [[ "$selected" == "✅ Nova Tarefa" ]]; then
        line="- [ ] ✅ $value - $time_value \\ [[$date_value]]"
    else
        line="- $emoji $value - $time_value \\ [[$date_value]]"
    fi

    append_capture_log "$file" "$line" || return 1
    notify "$emoji Registro salvo na daily $date_value"
}

open_daily_note() {
    local file mood vault_path relative_file uri
    file="$(daily_note_file)"
    if [[ ! -f "$file" ]]; then
        mood="$(choose_mood)" || return 0
        create_daily_note "$file" "$mood" || return 1
    fi

    vault_path="$(cd "$VAULT_DIR" && pwd -P)" || {
        notify "Vault não encontrada: $VAULT_DIR"
        return 1
    }
    file="$(cd "$(dirname "$file")" && pwd -P)/$(basename "$file")"
    case "$file" in
        "$vault_path"/*) relative_file="${file#"$vault_path"/}" ;;
        *)
            notify "A nota diária precisa estar dentro da Vault para abrir no Obsidian."
            return 1
            ;;
    esac

    uri="obsidian://open?vault=$(url_encode "$OBSIDIAN_VAULT_NAME")&file=$(url_encode "$relative_file")"
    if ! command -v xdg-open >/dev/null 2>&1; then
        notify "xdg-open não encontrado; não foi possível abrir o Obsidian."
        return 1
    fi
    xdg-open "$uri" >/dev/null 2>&1 &
}

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

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "vaultkit" "$1" 2>/dev/null || printf 'vaultkit: %s\n' "$1" >&2
    else
        printf 'vaultkit: %s\n' "$1" >&2
    fi
}

# Alias nomeados usados pelo vaultkit.sh (menu e CLI): mantêm a família daily_*
# documentada em lib/daily-note.sh sem duplicar implementação.
daily_add_log() { add_log "$@"; }
daily_open_note() { open_daily_note "$@"; }

# Garante que o template de fallback da note diária exista (mesmo formato do
# SendLog, com placeholders {{...}}). Nunca cria nada no vault, e vive em
# DATA_DIR/templates — fora de TEMPLATE_DIR, que é o catálogo de templates de
# snippet (ver TEMPLATE_FILE em lib/config.sh).
daily_ensure_template() {
    [[ -f "$TEMPLATE_FILE" ]] && return 0
    mkdir -p "$(dirname "$TEMPLATE_FILE")"
    cat > "$TEMPLATE_FILE" <<'TEMPLATE'
---
dateCreated: {{DATE}} @ {{TIME}}
tags:
  - calendar/dailynote
week: '[[{{WEEK}}]]'
daily-mood: "{{MOOD}}"
---
[[{{PREVIOUS_DATE}}|↶ Previous Day]] | [[{{NEXT_DATE}}|Following Day ↷]]

# {{DATE}}’s Note

// Daily quote
{{DAILY_QUOTE}}




---

# Capture


# Events

# Caderno
TEMPLATE
}
