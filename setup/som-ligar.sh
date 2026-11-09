#!/bin/bash
# SkyStation: toca o som de ligar logo no começo do boot (comando skystation-som-ligar).
# Roda como serviço do sistema, antes do console abrir, direto na placa de som (ALSA):
# a placa analógica (alto-falantes), não a de HDMI.
SOM=/opt/skystation/sounds/ligar.wav
[ -f "$SOM" ] || exit 0
[ -f /home/sky/.config/skystation/ligar.off ] && exit 0
card="$(awk '/^ *[0-9]+ \[/ && !/HDMI/ {print $1; exit}' /proc/asound/cards 2>/dev/null)"
exec aplay -q -D "plughw:${card:-0},0" "$SOM"
