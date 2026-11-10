#!/bin/bash
# SkyStation: diagnóstico do controle no PS2 (PCSX2).   Uso:  skystation-diag-ps2   (sem sudo)
H="$HOME"; [ "$(id -u)" -eq 0 ] && H="/home/sky"
INI="$H/.config/PCSX2/inis/PCSX2.ini"

echo "== Controles que o sistema vê"
awk '/^N: Name=/{n=$0} /^H: Handlers=.*js[0-9]/{sub(/^N: Name=/,"",n); print "  " n "   (" $0 ")"}' /proc/bus/input/devices
echo "== Permissões (joystick / hidraw)"
ls -l /dev/input/js* /dev/hidraw* 2>/dev/null | awk '{print "  " $1, $3, $4, $NF}'
echo "== PCSX2.ini: [UI] [InputSources] [Pad1]"
if [ -f "$INI" ]; then
    awk '/^\[(UI|InputSources|Pad1)\]/{p=1; print "  " $0; next} /^\[/{p=0} p && NF {print "    " $0}' "$INI" \
        | grep -E "^ +\\[|SetupWizard| SDL =|Keyboard|Type|Cross |Start |LUp " | head -20
    echo "    (Pad1 tem $(awk '/^\[Pad1\]/{p=1;next} /^\[/{p=0} p && /=/' "$INI" | wc -l) linhas)"
else
    echo "  (não existe: $INI)"
fi
echo "== Último jogo de PS2: linhas sobre controle"
LOG="$(ls -t "$H"/.local/state/skystation/games/ps2-*.log 2>/dev/null | head -1)"
if [ -n "$LOG" ]; then
    echo "  $(basename "$LOG")"
    grep -iE "sdl|gamepad|controller|joystick|pad [0-9]|input" "$LOG" | tail -15 | cut -c1-150 | sed 's/^/    /'
else
    echo "  (nenhum log de jogo de PS2 ainda)"
fi
