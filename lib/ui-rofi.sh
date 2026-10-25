#!/bin/bash

# =============================================================================
# ui-rofi.sh — Interface Rofi unificada (snippets + notas + blocos)
#Menus-base e tema: lib/rofi.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Snippet browser — formatação de entradas
# -----------------------------------------------------------------------------

short_path() {
    local dir="$1"
    [ "$dir" = "$SNIPPETS_DIR" ] && echo "/" || echo "${dir#$SNIPPETS_DIR/}"
}

# Formata linha de arquivo para exibição no rofi
# $1=arquivo  $2=mostrar_pasta(0|1)
_fmt_file_entry() {
    local file="$1"
    local show_dir="${2:-0}"
    local name tags tag_str right ts rel

    name="$(basename "$file" .md)"

    tags="$(get_snippet_tags "$file" | head -3 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"

    ts="$(stat -c %Y "$file" 2>/dev/null || echo 0)"
    rel="$(rel_time "$ts")"

    if [ "$show_dir" -eq 1 ]; then
        local parent
        parent="${file#$SNIPPETS_DIR/}"
        parent="$(dirname "$parent")"
        [ "$parent" = "." ] && parent=""
        [ -n "$tags" ] && right="${parent:+$parent · }${tags} · ${rel}" || right="${parent:+$parent · }${rel}"
    else
        [ -n "$tags" ] && right="${tags} · ${rel}" || right="$rel"
    fi

    local name_len right_len pad total=72
    name_len="${#name}"
    right_len="${#right}"
    pad=$(( total - name_len - right_len ))
    [ "$pad" -lt 2 ] && pad=2

    printf "%s%*s%s" "$name" "$pad" "" "$right"
}

# Formata linha de pasta para exibição no rofi
_fmt_dir_entry() {
    local subdir="$1"
    local dname count ts_recent rel right name_part

    dname="$(basename "$subdir")"
    count="$(find "$subdir" -mindepth 1 -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)"

    ts_recent="$(find "$subdir" -mindepth 1 -maxdepth 1 -type f -name "*.md" \
        -printf "%T@\n" 2>/dev/null | sort -rn | head -1 | cut -d. -f1)"

    if [ -n "$ts_recent" ] && [ "$ts_recent" -gt 0 ] 2>/dev/null; then
        rel="$(rel_time "$ts_recent")"
        [ "$count" -eq 1 ] && right="1 snippet · ${rel}" || right="${count} · ${rel}"
    elif [ "$count" -gt 0 ]; then
        [ "$count" -eq 1 ] && right="1 snippet" || right="${count} "
    else
        right="vazio"
    fi

    name_part="${dname}"
    local name_len right_len pad total=72
    name_len="${#name_part}"
    right_len="${#right}"
    pad=$(( total - name_len - right_len ))
    [ "$pad" -lt 2 ] && pad=2

    printf "%s%*s%s" "$name_part" "$pad" "" "$right"
}

# -----------------------------------------------------------------------------
# Listagem do navegador de snippets
# Formato: col1_visível \t TIPO \t caminho
# Tipos: UP, DIR, FILE, SEP
# -----------------------------------------------------------------------------

list_entries() {
    local dir="$1"
    local sort_mode="$2"

    [ "$dir" != "$SNIPPETS_DIR" ] && printf "← ..\tUP\t%s\n" "$(dirname "$dir")"

    while IFS= read -r subdir; do
        printf "%s\tDIR\t%s\n" "$(_fmt_dir_entry "$subdir")" "$subdir"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | sort -f)

    if [ "$sort_mode" = "recent" ]; then
        while IFS= read -r -d '' file; do
            printf "%s\tFILE\t%s\n" "$(_fmt_file_entry "$file" 0)" "$file"
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -name "*.md" \
            -printf "%T@\t%p\0" 2>/dev/null | sort -rznk1 | \
            while IFS=$'\t' read -r -d '' _ts path; do printf "%s\0" "$path"; done)
    else
        while IFS= read -r -d '' file; do
            printf "%s\tFILE\t%s\n" "$(_fmt_file_entry "$file" 0)" "$file"
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -name "*.md" -print0 \
            2>/dev/null | sort -z)
    fi
}

list_history() {
    while IFS= read -r file; do
        [ -z "$file" ] || [ ! -f "$file" ] && continue
        printf "🕐  %s\tFILE\t%s\n" "$(_fmt_file_entry "$file" 0)" "$file"
    done < "$HISTORY_FILE"
}

list_favorites() {
    while IFS= read -r file; do
        [ -z "$file" ] || [ ! -f "$file" ] && continue
        printf "⭐  %s\tFILE\t%s\n" "$(_fmt_file_entry "$file" 0)" "$file"
    done < "$FAVORITES_FILE"
}

# -----------------------------------------------------------------------------
# Preview de snippet
# -----------------------------------------------------------------------------

get_snippet_preview() {
    local file="$1"
    local code
    code="$(block_content "$file" 1)"

    local lines total
    lines="$(echo "$code" | head -n "$PREVIEW_LINES" | while IFS= read -r line; do
        echo "$line" | tr '\r' ' ' | sed 's/\t/    /g' | cut -c 1-80
    done)"

    total=$(echo "$code" | wc -l)
    [ "$total" -gt "$PREVIEW_LINES" ] && lines="$(echo "$lines"; echo "  ... (+$((total - PREVIEW_LINES)) linhas)")"

    echo "$lines"
}

# -----------------------------------------------------------------------------
# Ações sobre um snippet
# -----------------------------------------------------------------------------

show_actions() {
    local file="$1"
    local name preview action

    name="$(basename "$file" .md)"
    preview="$(get_snippet_preview "$file")"

    local fav_label
    is_favorite "$file" && fav_label="Desfavoritar" || fav_label="Favoritar"

    local block_count=0
    block_count=$(extract_blocks "$file" | wc -l)

    local options
    options="$(printf "Copiar\nDigitar\nEditar\nGerenciar tags\nApagar\n%s" "$fav_label")"

    action=$(echo "$options" | rofi_menu \
        -p "$name" \
        -mesg "$preview") || return 0

    case "$action" in
        "Copiar")
            local code block_idx
            if (( block_count > 1 )); then
                block_idx=$(
                    extract_blocks "$file" | while IFS=$'\t' read -r idx lang start end preview; do
                        printf "bloco %s  %s  %s\n" "$idx" "${lang:-text}" "$preview"
                    done | rofi_menu -p "bloco" -mesg "$name tem $block_count blocos"
                ) || return 0
                [[ -z "$block_idx" ]] && return 0
                read -r _ block_idx _ <<< "$block_idx"
                code="$(block_content "$file" "$block_idx")"
            else
                code="$(block_content "$file" 1)"
            fi
            echo -n "$code" | copy_to_clipboard
            add_to_history "$file"
            notify-send "vaultkit" "\"$name\" copiado."
            return 99
            ;;
        "Digitar")
            local code block_idx
            if (( block_count > 1 )); then
                block_idx=$(
                    extract_blocks "$file" | while IFS=$'\t' read -r idx lang start end preview; do
                        printf "bloco %s  %s  %s\n" "$idx" "${lang:-text}" "$preview"
                    done | rofi_menu -p "bloco" -mesg "$name tem $block_count blocos"
                ) || return 0
                [[ -z "$block_idx" ]] && return 0
                read -r _ block_idx _ <<< "$block_idx"
                code="$(block_content "$file" "$block_idx")"
            else
                code="$(block_content "$file" 1)"
            fi
            if (( ${#code} > 5000 )); then
                code="${code:0:5000}"
            fi
            add_to_history "$file"
            sleep 0.5
            type_text "$code" 50
            return 99
            ;;
        "Editar")
            "$EDITOR_APP" "$file"
            ;;
        "Gerenciar tags")
            manage_tags "$file"
            ;;
        "Apagar")
            confirm_delete "$file"
            ;;
        "Favoritar"|"Desfavoritar")
            toggle_favorite "$file"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Gerenciamento de tags via Rofi
# -----------------------------------------------------------------------------

manage_tags() {
    local file="$1"
    local name
    name="$(basename "$file" .md)"

    while true; do
        local current_tags
        current_tags="$(get_snippet_tags "$file")"

        local options=""
        while IFS= read -r tag; do
            [ -z "$tag" ] && continue
            options="${options}${tag}  x remover\n"
        done <<< "$current_tags"
        options="${options}+ adicionar tag\nVoltar"

        local tag_summary=""
        [ -n "$current_tags" ] \
            && tag_summary="Tags: $(echo "$current_tags" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')" \
            || tag_summary="Sem tags"

        local choice
        choice=$(printf "%b" "$options" | rofi_menu \
            -p "$name" \
            -mesg "$tag_summary") || return 0
        [ -z "$choice" ] && return 0

        case "$choice" in
            "+ adicionar tag")
                local vault_tags new_tag
                vault_tags="$(collect_all_tags)"

                new_tag=$(printf "%b" "$vault_tags" | rofi_menu \
                    -p "nova tag (ou digite)") || continue
                [ -z "$new_tag" ] && continue

                if echo "$current_tags" | grep -qiEx "$new_tag"; then
                    notify-send "vaultkit" "Tag \"$new_tag\" ja existe."
                    continue
                fi

                _tag_add "$file" "$new_tag"
                notify-send "vaultkit" "Tag \"$new_tag\" adicionada."
                ;;

            "Voltar"|"")
                return 0
                ;;

            *"  x remover")
                local tag_to_remove
                tag_to_remove="$(echo "$choice" | sed 's/  x remover$//')"
                _tag_remove "$file" "$tag_to_remove"
                notify-send "vaultkit" "Tag \"$tag_to_remove\" removida."
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Criação de snippets e grupos
# -----------------------------------------------------------------------------

# Escape \ and & for safe use in bash parameter expansion replacement strings
_escape_replacement() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//&/\\&}"
    printf '%s' "$s"
}

new_snippet() {
    local current_dir="$1"
    local name
    name=$(rofi_menu -p "+ trecho") || return 0
    [ -z "$name" ] && return 0

    local clean_name file_path
    clean_name="$(safe_filename "$name")"
    file_path="$current_dir/${clean_name}.md"

    if [ -d "$TEMPLATE_DIR" ] && [ "$(ls -A "$TEMPLATE_DIR" 2>/dev/null)" ]; then
        local template
        template=$(ls "$TEMPLATE_DIR" | rofi_menu -p "Template (Esc=padrao)") || true
        if [ -n "$template" ] && [ -f "$TEMPLATE_DIR/$template" ]; then
            local clipboard_content template_content
            clipboard_content="$(read_clipboard 2>/dev/null || true)"
            template_content="$(<"$TEMPLATE_DIR/$template")"

            local escaped_name escaped_clip
            escaped_name="$(_escape_replacement "$name")"
            escaped_clip="$(_escape_replacement "$clipboard_content")"

            template_content="${template_content//\{\{TITLE\}\}/$escaped_name}"
            template_content="${template_content//\{\{DATE\}\}/$DATE_FORMAT}"
            template_content="${template_content//\{\{CLIPBOARD\}\}/$escaped_clip}"
            printf '%s\n' "$template_content" > "$file_path"
        else
            _default_snippet "$file_path" "$name"
        fi
    else
        _default_snippet "$file_path" "$name"
    fi

    "$EDITOR_APP" "$file_path"
}

_default_snippet() {
    local file_path="$1"
    local name="$2"
    cat > "$file_path" <<EOF
---
title: $name
tags: []
dateCreated: "[[$DATE_FORMAT]]"
---

\`\`\`
$(read_clipboard 2>/dev/null || true)
\`\`\`
EOF
}

create_group() {
    local current_dir="$1"
    local name
    name=$(rofi_menu -p "+ grupo") || return 0
    [ -z "$name" ] && return 0

    local clean_name
    clean_name="$(safe_dirname "$name")"
    mkdir -p "$current_dir/$clean_name"
    notify-send "vaultkit" "Grupo: $clean_name"
    echo "$current_dir/$clean_name"
}

confirm_delete() {
    local file="$1"
    local name check
    name="$(basename "$file" .md)"
    check=$(echo -e "Nao\nSim" | rofi_menu -p "Apagar '$name'?") || return 0
    if [ "$check" = "Sim" ]; then
        rm "$file"
        notify-send "vaultkit" "\"$name\" apagado."
    fi
}

# -----------------------------------------------------------------------------
# Trocar pasta via Rofi
# -----------------------------------------------------------------------------
_switch_folder() {
    local current="$1"
    local entries choice

    entries=". (raiz)"
    local folders
    folders=$(list_snippet_folders "$SNIPPETS_DIR")
    if [ -n "$folders" ]; then
        while IFS=$'\t' read -r name count; do
            entries="$(printf '%s\n' "$entries" "$name ($count snippets)")"
        done <<< "$folders"
    fi
    entries="$(printf '%s\n' "$entries" "+ criar nova pasta")"

    choice=$(printf '%s\n' "$entries" | rofi_menu -p "ir para pasta") || { _switch_result="$current"; return; }
    [ -z "$choice" ] && { _switch_result="$current"; return; }

    if [[ "$choice" == "+ criar nova pasta" ]]; then
        local name clean
        name=$(rofi_menu -p "nome da pasta") || { _switch_result="$current"; return; }
        [ -z "$name" ] && { _switch_result="$current"; return; }
        clean="$(safe_filename "$name")"
        mkdir -p "$SNIPPETS_DIR/$clean"
        _switch_result="$SNIPPETS_DIR/$clean"
    elif [[ "$choice" == ". (raiz)" ]]; then
        _switch_result="$SNIPPETS_DIR"
    else
        local folder_name
        folder_name=$(echo "$choice" | sed 's/ ([0-9]* snippets)$//')
        _switch_result="$SNIPPETS_DIR/$folder_name"
    fi
}

# Seletor de pasta de destino (para salvar blocos)
_pick_target_folder() {
    local source_file="${1:-}" block_idx="${2:-}"

    local entries=""
    local ws_num=1

    # Check membership if source info provided
    local membership_info=""
    if [ -n "$source_file" ] && [ -n "$block_idx" ]; then
        ensure_workspace_cache
        local containing_ws
        containing_ws=$(block_in_workspace "$source_file" "$block_idx")
        [ -n "$containing_ws" ] && membership_info="$containing_ws"
    fi

    local folders
    folders=$(list_snippet_folders "$SNIPPETS_DIR")
    [[ -n "$folders" ]] && while IFS=$'\t' read -r name count; do
        local indicator=""
        if [ -n "$membership_info" ]; then
            echo "$membership_info" | grep -qFx "$name" && indicator=" * contem este bloco"
        fi
        entries="${entries}${ws_num}. ${name} (${count} snippets)${indicator}\n"
        ((ws_num++))
    done <<< "$folders"
    entries="$(printf "%b. (raiz)\n+ criar nova pasta" "$entries")"

    local choice
    choice=$(printf '%b' "$entries" | rofi_menu -p "salvar em") || return 1
    [ -z "$choice" ] && return 1

    if [[ "$choice" == "+ criar nova pasta" ]]; then
        local name
        name=$(rofi_menu -p "nome da pasta") || return 1
        [ -z "$name" ] && return 1
        local clean
        clean="$(safe_filename "$name")"
        printf '%s' "$SNIPPETS_DIR/$clean"
    elif [[ "$choice" == *"(raiz)"* ]]; then
        printf '%s' "$SNIPPETS_DIR"
    else
        local folder_name
        folder_name=$(echo "$choice" | sed 's/^[0-9]*\. //' | sed 's/ ([0-9]* snippets.*$//' | sed 's/ \*.*$//')
        printf '%s' "$SNIPPETS_DIR/$folder_name"
    fi
}

# -----------------------------------------------------------------------------
# Exportar — pede o caminho de destino via Rofi
# Enter em branco → exporta na base da pasta de snippets.
# Caminho terminando em .tar.gz → grava nesse arquivo exato;
# caso contrário → tratado como pasta e o nome do arquivo é gerado.
# -----------------------------------------------------------------------------

_export_flow() {
    local dest_dir archive_file=""

    dest_dir=$(rofi_menu -p "destino do export") || return 0
    [ -z "$dest_dir" ] && dest_dir="$SNIPPETS_DIR"

    dest_dir="${dest_dir%/}"

    if [[ "$dest_dir" == *.tar.gz ]]; then
        archive_file="$dest_dir"
        dest_dir="$(dirname "$dest_dir")"
    fi

    if ! mkdir -p "$dest_dir" 2>/dev/null; then
        notify-send "vaultkit" "Nao foi possivel criar destino: $dest_dir"
        return 1
    fi
    if [ ! -w "$dest_dir" ]; then
        notify-send "vaultkit" "Destino sem permissao de escrita: $dest_dir"
        return 1
    fi

    export_snippets "$dest_dir" "$archive_file"
}

# -----------------------------------------------------------------------------
# Configurações visuais via Rofi
# -----------------------------------------------------------------------------


open_settings() {
    while true; do
        local cur_vault cur_snippets cur_editor cur_sort cur_hist cur_prev cur_width
        cur_vault="${VAULT_DIR}"
        cur_snippets="${SNIPPETS_DIR}"
        cur_editor="${EDITOR_APP}"
        cur_sort="${DEFAULT_SORT}"
        cur_hist="${HISTORY_LIMIT}"
        cur_prev="${PREVIEW_LINES}"
        cur_width="${ROFI_WINDOW_WIDTH:-510px}"

        local options choice
        options="$(printf \
            "Pasta do vault: %s\nPasta de snippets: %s\nPasta notas diárias: %s\nVault Obsidian: %s\nTemplate diária: %s\nEditor: %s\nOrdenacao: %s\nLimite historico: %s\nPreview linhas: %s\nLargura janela: %s\nExportar snippets\nImportar snippets\nAbrir config no editor\nVoltar" \
            "$cur_vault" "$cur_snippets" "$DAILY_NOTES_DIR" "$OBSIDIAN_VAULT_NAME" "$DAILY_NOTE_TEMPLATE" "$cur_editor" "$cur_sort" "$cur_hist" "$cur_prev" "$cur_width")"

        choice=$(echo "$options" | rofi_menu -p "configuracoes") || return 0

        case "$choice" in
            "Pasta do vault:"*)
                local new_val
                new_val=$(echo "$cur_vault" | rofi_menu -p "Pasta do vault") || continue
                [ -z "$new_val" ] && continue
                VAULT_DIR="$new_val"
                mkdir -p "$VAULT_DIR"
                OBSIDIAN_VAULT_NAME="$(basename "$VAULT_DIR")"
                save_config
                notify-send "vaultkit" "Vault: $VAULT_DIR"
                ;;
            "Pasta de snippets:"*)
                local new_val
                new_val=$(echo "$cur_snippets" | rofi_menu -p "Pasta de snippets") || continue
                [ -z "$new_val" ] && continue
                SNIPPETS_DIR="$new_val"
                mkdir -p "$SNIPPETS_DIR"
                save_config
                notify-send "vaultkit" "Snippets: $SNIPPETS_DIR"
                ;;
            "Pasta notas diárias:"*)
                local new_val
                new_val=$(echo "$DAILY_NOTES_DIR" | rofi_menu -p "Pasta das notas diárias (relativa ao vault)") || continue
                [ -z "$new_val" ] && continue
                DAILY_NOTES_DIR="$new_val"
                save_config
                notify-send "vaultkit" "Notas diárias: $(daily_notes_path)"
                ;;
            "Vault Obsidian:"*)
                local new_val
                new_val=$(echo "$OBSIDIAN_VAULT_NAME" | rofi_menu -p "Nome da vault no Obsidian") || continue
                [ -z "$new_val" ] && continue
                OBSIDIAN_VAULT_NAME="$new_val"
                save_config
                notify-send "vaultkit" "Vault Obsidian: $OBSIDIAN_VAULT_NAME"
                ;;
            "Template diária:"*)
                local new_val
                new_val=$(echo "$DAILY_NOTE_TEMPLATE" | rofi_menu -p "Caminho do template da diária") || continue
                [ -z "$new_val" ] && continue
                DAILY_NOTE_TEMPLATE="$(normalize_path "$new_val" "$VAULT_DIR")"
                save_config
                daily_ensure_template
                notify-send "vaultkit" "Template diária: $DAILY_NOTE_TEMPLATE"
                ;;
            "Editor:"*)
                local new_val
                new_val=$(echo "$cur_editor" | rofi_menu -p "Editor") || continue
                [ -z "$new_val" ] && continue
                EDITOR_APP="$new_val"
                save_config
                notify-send "vaultkit" "Editor: $EDITOR_APP"
                ;;
            "Ordenacao:"*)
                local new_val
                new_val=$(printf "recent\naz" | rofi_menu -p "Ordenacao") || continue
                [ -z "$new_val" ] && continue
                DEFAULT_SORT="$new_val"
                save_config
                ;;
            "Limite historico:"*)
                local new_val
                new_val=$(echo "$cur_hist" | rofi_menu -p "Limite historico") || continue
                [ -z "$new_val" ] && continue
                HISTORY_LIMIT="$new_val"
                save_config
                ;;
            "Preview linhas:"*)
                local new_val
                new_val=$(echo "$cur_prev" | rofi_menu -p "Preview linhas") || continue
                [ -z "$new_val" ] && continue
                PREVIEW_LINES="$new_val"
                save_config
                ;;
            "Largura janela:"*)
                local new_val
                new_val=$(echo "$cur_width" | rofi_menu -p "Largura da janela (ex.: 510px)") || continue
                new_val="${new_val//[[:space:]]/}"
                if [[ "$new_val" =~ ^[0-9]+$ ]]; then
                    new_val="${new_val}px"
                fi
                if [[ ! "$new_val" =~ ^[0-9]+(px|%|em)$ ]]; then
                    notify-send "vaultkit" "Largura invalida: '$new_val'. Use ex.: 510px"
                    continue
                fi
                ROFI_WINDOW_WIDTH="$new_val"
                save_config
                notify-send "vaultkit" "Largura da janela: $ROFI_WINDOW_WIDTH"
                ;;
            "Exportar snippets")
                _export_flow
                ;;
            "Importar snippets")
                local archive
                archive=$(rofi_menu -p "Caminho do .tar.gz") || continue
                [ -z "$archive" ] && continue
                if [ ! -f "$archive" ]; then
                    notify-send "vaultkit" "Arquivo nao encontrado."
                    continue
                fi
                import_snippets "$archive"
                ;;
            "Abrir config no editor")
                "$EDITOR_APP" "$CONFIG_FILE"
                load_config
                ;;
            "Voltar"|"")
                return 0
                ;;
        esac
    done
}

# Create default templates
create_default_templates() {
    mkdir -p "$TEMPLATE_DIR"

    [ -f "$TEMPLATE_DIR/default.md" ] && return

    cat > "$TEMPLATE_DIR/default.md" <<'TMPL'
---
title: {{TITLE}}
tags: []
dateCreated: "[[{{DATE}}]]"
---

```
{{CLIPBOARD}}
```
TMPL

    cat > "$TEMPLATE_DIR/function.md" <<'TMPL'
---
title: {{TITLE}}
tags:
  - function
dateCreated: "[[{{DATE}}]]"
---

```javascript
{{CLIPBOARD}}
```
TMPL

    cat > "$TEMPLATE_DIR/notes.md" <<'TMPL'
---
title: {{TITLE}}
tags:
  - notes
dateCreated: "[[{{DATE}}]]"
---

## {{TITLE}}

{{CLIPBOARD}}
TMPL
}
