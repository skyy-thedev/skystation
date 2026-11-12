#!/bin/bash
# SkyStation: toca o som de ligar logo no começo do boot (comando skystation-som-ligar).
# Roda como serviço do sistema, antes do console abrir, direto na placa de som (ALSA).
#   - TV ligada no HDMI/DisplayPort: o som sai na TV (mesma regra do Modo TV; "tv-som.off" desliga)
#   - sem TV (ou se a TV não aceitar): alto-falantes do console
# Os caminhos podem ser trocados por variáveis (SKY_PROC, SKY_SYS, SKY_APLAY…) para testar sem hardware.
SONS="${SKY_SONS:-/opt/skystation/sounds}"
CONF="${SKY_CONF:-/home/sky/.config/skystation}"
PROC="${SKY_PROC:-/proc}"
SYS="${SKY_SYS:-/sys}"
APLAY="${SKY_APLAY:-aplay}"
ESPERA="${SKY_ESPERA:-16}"          # meias-voltas de 0,5 s esperando a TV se apresentar (8 s)
SOM="$SONS/ligar.wav"
[ -f "$SOM" ] || exit 0
[ -f "$CONF/ligar.off" ] && exit 0

tv_conectada() {
    [ -f "$CONF/tv-som.off" ] && return 1
    local s
    for s in "$SYS"/class/drm/card*-HDMI-*/status "$SYS"/class/drm/card*-DP-*/status; do
        [ -f "$s" ] && [ "$(cat "$s" 2>/dev/null)" = "connected" ] && return 0
    done
    return 1
}

# Placa cujo HDMI já enxergou a TV: o driver publica isso em /proc/asound/cardN/eld#…
placa_da_tv() {
    local f
    for f in "$PROC"/asound/card*/eld#*; do
        [ -f "$f" ] || continue
        if grep -q '^monitor_present[[:space:]]*1' "$f" && grep -q '^eld_valid[[:space:]]*1' "$f"; then
            f="${f%/eld#*}"; echo "${f##*card}"; return 0
        fi
    done
    return 1
}

tocar_na_tv() {
    local card="" i dev ok=1 pids="" p tvsom="$SONS/ligar-tv.wav"
    [ -f "$tvsom" ] || tvsom="$SOM"
    for ((i = 0; i < ESPERA; i++)); do
        card="$(placa_da_tv)" && break
        sleep 0.5
    done
    [ -n "$card" ] || return 1
    if command -v amixer >/dev/null 2>&1 && [ -z "${SKY_PROC:-}" ]; then
        for i in 0 1 2 3; do amixer -q -c "$card" sset "IEC958,$i" on >/dev/null 2>&1; done
    fi
    # Toca em todas as saídas HDMI dessa placa ao mesmo tempo: só a que tem TV faz som de verdade.
    while read -r dev; do
        "$APLAY" -q -D "plughw:$card,$dev" "$tvsom" 2>/dev/null &
        pids="$pids $!"
    done < <(awk -F'[-:]' -v c="$card" '$1+0 == c+0 && /HDMI|DisplayPort/ && /playback/ {print $2+0}' "$PROC/asound/pcm" 2>/dev/null)
    for p in $pids; do wait "$p" && ok=0; done
    return $ok
}

if tv_conectada && tocar_na_tv; then
    exit 0
fi
# Alto-falantes: primeira saída que não é HDMI.
read -r card dev < <(awk -F'[-:]' '!/HDMI|DisplayPort/ && /playback/ {print $1+0, $2+0; exit}' "$PROC/asound/pcm" 2>/dev/null)
exec "$APLAY" -q -D "plughw:${card:-0},${dev:-0}" "$SOM"
