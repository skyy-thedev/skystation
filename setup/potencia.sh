#!/bin/bash
# SkyStation: potência do processador durante os jogos (comando skystation-potencia, roda como root).
# O sky-run pede "jogo" ao abrir um jogo e "normal" ao fechar, escrevendo em
# /var/lib/skystation/pedidos/potencia. Em "jogo": governador performance e preferência de energia
# no máximo, para o processador não ficar em frequência baixa enquanto as threads do emulador
# esperam umas pelas outras. Em "normal": volta ao que estava.
P=/var/lib/skystation/pedidos/potencia
ORIG=/run/skystation-potencia.orig
modo="${1:-$(cat "$P" 2>/dev/null)}"
rm -f "$P"
set_all() { for f in $1; do [ -w "$f" ] && echo "$2" >"$f" 2>/dev/null; done; }
GOV="/sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
EPP="/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
PROF=/sys/firmware/acpi/platform_profile
case "$modo" in
jogo)
    if [ ! -f "$ORIG" ]; then
        {
            echo "gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
            echo "epp=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)"
            echo "prof=$(cat "$PROF" 2>/dev/null)"
        } >"$ORIG"
    fi
    set_all "$GOV" performance
    set_all "$EPP" performance
    [ -w "$PROF" ] && grep -qw performance /sys/firmware/acpi/platform_profile_choices 2>/dev/null && echo performance >"$PROF" 2>/dev/null
    ;;
normal)
    [ -f "$ORIG" ] || exit 0
    . "$ORIG"
    [ -n "$gov" ] && set_all "$GOV" "$gov"
    [ -n "$epp" ] && set_all "$EPP" "$epp"
    [ -n "$prof" ] && [ -w "$PROF" ] && echo "$prof" >"$PROF" 2>/dev/null
    rm -f "$ORIG"
    ;;
esac
exit 0
