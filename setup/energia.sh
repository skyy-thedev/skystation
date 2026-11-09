#!/bin/bash
# SkyStation: perfil de energia da CPU (comando skystation-energia; roda como root).
#   na tomada  -> balance_performance (o GameMode ainda sobe para "performance" durante os jogos)
#   na bateria -> balance_power (menos calor, mais minutos de jogo)
# Chamado pelo udev quando o carregador entra/sai e por um timer a cada minuto
# (o GameMode devolve a CPU ao padrão quando o jogo fecha).
#
# Fase 5.7: "Ligar pelo controle". No modo de espera, controles e teclados USB e o rádio
# Bluetooth podem acordar o console. Desligar: Sistema -> Ligar pelo controle (cria
# ~sky/.config/skystation/acordar.off). Do desligado total nenhum controle liga o notebook:
# isso depende da placa, que só liga pelo botão.
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

# ---- acordar pelo controle (modo de espera)
want="enabled"
[ -f /home/sky/.config/skystation/acordar.off ] && want="disabled"
for d in /sys/bus/usb/devices/*; do
    [ -f "$d/power/wakeup" ] || continue
    classes="$(cat "$d/bDeviceClass" "$d"/*/bInterfaceClass 2>/dev/null | sort -u | tr '\n' ' ')"
    case " $classes " in
        *" 03 "*|*" e0 "*|*" 09 "*) ;;   # HID (controle/teclado), rádio sem fio (Bluetooth), hubs
        *) continue ;;
    esac
    [ "$(cat "$d/power/wakeup")" = "$want" ] || echo "$want" >"$d/power/wakeup" 2>/dev/null
done
# controladores USB na tabela ACPI (escrever o nome alterna o estado: só mexe se precisar)
if [ -w /proc/acpi/wakeup ]; then
    while read -r dev _ state _; do
        case "$dev" in XHC*|EHC*|EHCI*|XHCI*) ;; *) continue ;; esac
        cur="${state#\*}"
        [ "$cur" = "$want" ] || echo "$dev" >/proc/acpi/wakeup 2>/dev/null
    done < <(tail -n +2 /proc/acpi/wakeup)
fi
exit 0
