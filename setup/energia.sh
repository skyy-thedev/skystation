#!/bin/bash
# SkyStation: perfil de energia da CPU (comando skystation-energia; roda como root).
#   na tomada  -> balance_performance (o GameMode ainda sobe para "performance" durante os jogos)
#   na bateria -> balance_power (menos calor, mais minutos de jogo)
# Chamado pelo udev quando o carregador entra/sai e por um timer a cada minuto
# (o GameMode devolve a CPU ao padrão quando o jogo fecha).
ac=1
for s in /sys/class/power_supply/*; do
    [ "$(cat "$s/type" 2>/dev/null)" = "Mains" ] && ac="$(cat "$s/online" 2>/dev/null)"
done
if [ "$ac" = "0" ]; then epp="balance_power"; else epp="balance_performance"; fi
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -w "$f" ] || continue
    [ "$(cat "$f")" = "performance" ] && continue   # jogo aberto com GameMode: não mexe
    [ "$(cat "$f")" = "$epp" ] || echo "$epp" >"$f" 2>/dev/null
done
exit 0
