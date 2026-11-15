#!/bin/bash
# SkyStation: diagnóstico de controles, USB e Bluetooth.   Uso:  sudo skystation-diag-controle
OUT="/home/sky/skystation/diag-controle.txt"
{
echo "== $(date)  |  $(cat /opt/skystation/VERSION 2>/dev/null)"
echo; echo "== módulos";       lsmod | grep -E "hid_playstation|hid_sony|uhid|btusb|ath3k|xpad" || echo "(nenhum)"
echo; echo "== adaptador (placa Wi-Fi/Bluetooth)"; lspci -nn 2>/dev/null | grep -i -E "network|wireless|wi-fi|bluetooth"
lsusb 2>/dev/null | grep -i -E "bluetooth|realtek|mediatek|intel corp.*(bluetooth|wireless)|0bda:|0e8d:|8087:|13d3:|0489:"
echo "serviço bluetooth: $(systemctl is-active bluetooth 2>&1) / $(systemctl is-enabled bluetooth 2>&1)"
echo; echo "== rfkill";        rfkill list 2>&1
echo; echo "== kernel: firmware do Bluetooth"; dmesg | grep -i -E "bluetooth.*(firmware|fw|hci0)|btusb|btrtl|btmtk|btintel|direct firmware" | tail -25
echo; echo "== bluetooth";     bluetoothctl show 2>&1 | grep -E "Controller|Powered|Pairable"
bluetoothctl devices Paired 2>&1 | while read -r _ mac name; do
    echo "-- $name ($mac)"; bluetoothctl info "$mac" | grep -E "Paired|Bonded|Trusted|Connected|UUID: Human"; done
echo; echo "== serviço bluetooth (últimas linhas)"; journalctl -b -u bluetooth --no-pager | tail -15
echo; echo "== kernel: hid/sony/playstation/bluetooth/usb (últimas 40)"
dmesg | grep -i -E "sony|playstation|hid|bluetooth|usb [0-9]|xhci|ehci|over-current" | tail -40
echo; echo "== árvore USB";    lsusb -t 2>&1; echo; lsusb 2>&1
echo; echo "== controles vistos pelo sistema"; ls -l /dev/input/by-id/ 2>&1 | grep -i -E "joy|event-joystick|gamepad" || echo "(nenhum)"
} > "$OUT" 2>&1
chown sky:sky "$OUT" 2>/dev/null || true
# cópia no HD/pendrive SKYROMS: dá para ler (e mandar) direto do Windows
[ -w /mnt/skyroms ] && cp -f "$OUT" /mnt/skyroms/diag-controle.txt 2>/dev/null && echo "Cópia em SKYROMS/diag-controle.txt"
cat "$OUT"
echo; echo "Salvo em $OUT"
