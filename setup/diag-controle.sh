#!/bin/bash
# SkyStation: diagnóstico de controles, USB e Bluetooth.   Uso:  sudo skystation-diag-controle
OUT="/home/sky/skystation/diag-controle.txt"
{
echo "== $(date)  |  $(cat /opt/skystation/VERSION 2>/dev/null)"
echo; echo "== módulos";       lsmod | grep -E "hid_playstation|hid_sony|uhid|btusb|ath3k|xpad" || echo "(nenhum)"
echo; echo "== rfkill";        rfkill list 2>&1
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
cat "$OUT"
echo; echo "Salvo em $OUT"
