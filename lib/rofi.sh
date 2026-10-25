#!/bin/bash

# =============================================================================
# rofi.sh — Camada base de interface Rofi (menus + tema)
# Unificada: base do rofi_menu do mdsnip (mais completa); substitui a versão
# simples do SendLog.
# =============================================================================

ROFI_THEME_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/simple-tokyonight.rasi"

# Tema-extra do dmenu. Construído dinamicamente para refletir ROFI_WINDOW_WIDTH
# (definido em config.sh por load_config, depois deste arquivo ser carregado).
_rofi_theme() {
    printf 'window   { width: %s; }\n' "${ROFI_WINDOW_WIDTH:-510px}"
    printf 'listview { lines: 17; spacing: 2px; }\n'
    printf 'inputbar { padding: 6px 8px; }\n'
    printf 'element  { padding: 4px 8px; }\n'
    printf 'element-text { font: "JetBrains Mono 9, Monospace 10"; }\n'
}

rofi_menu() {
    local extra_args=()
    [ "$XDG_SESSION_TYPE" = "wayland" ] && extra_args+=("-normal-window")
    local theme_args=()
    [ -f "$ROFI_THEME_FILE" ] && theme_args+=("-theme" "$ROFI_THEME_FILE")
    local theme_str
    theme_str="$(_rofi_theme)"
    # GNOME (Mutter) nao implementa wlr-layer-shell exigido pelo rofi 2.0 no
    # Wayland: forca backend X11 via XWayland apenas nesse caso. Outros
    # compositores (Sway/Hyprland) continuam no layer-shell nativo.
    if [ "$XDG_SESSION_TYPE" = "wayland" ] && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
        WAYLAND_DISPLAY= GDK_BACKEND=x11 \
            rofi -dmenu -i "${extra_args[@]}" "${theme_args[@]}" -theme-str "$theme_str" "$@"
    else
        rofi -dmenu -i "${extra_args[@]}" "${theme_args[@]}" -theme-str "$theme_str" "$@"
    fi
}
