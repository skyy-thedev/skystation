#!/bin/bash
# SkyStation: Fase 5.8 — jogar direto do disco (CD de PS1, DVD/CD de PS2) no leitor do console.
# Uso:  sudo bash /opt/skystation-src/setup/fase5-8.sh      (na VM: /mnt/skystation/setup/fase5-8.sh)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_NAME="sky"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

echo "==> [1/3] Console (sky-disco, sky-notify, launcher, sky-emu)"
bash "$SRC/setup/atualizar.sh"

echo "==> [2/3] Acesso ao leitor de CD/DVD"
# O PCSX2 lê o DVD pelo /dev/sr0; o core de PS1 manda comandos SCSI pelo /dev/sgN
# (é assim que ele lê as faixas de áudio do CD). O módulo "sg" cria esse /dev/sgN.
echo sg >/etc/modules-load.d/skystation-sg.conf
modprobe sg 2>/dev/null || true
getent group optical >/dev/null || groupadd -r optical
usermod -aG optical "$USER_NAME"
cat >/etc/udev/rules.d/71-skystation-disco.rules <<'RULES'
# SkyStation (Fase 5.8): o usuário do console lê o disco (sr) e conversa com o leitor (sg).
SUBSYSTEM=="block", KERNEL=="sr[0-9]*", GROUP="optical", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="scsi_generic", SUBSYSTEMS=="scsi", ATTRS{type}=="5", GROUP="optical", MODE="0660", TAG+="uaccess"
RULES
udevadm control --reload-rules || true
udevadm trigger --subsystem-match=block --subsystem-match=scsi_generic --action=change || true

echo "==> [3/3] Conferindo o leitor"
found=0
for d in /sys/class/block/sr[0-9]*; do
    [ -e "$d" ] || continue
    found=1
    sg="$(ls "$d/device/scsi_generic" 2>/dev/null | head -1)"
    echo "    Leitor: /dev/$(basename "$d")  ($(cat "$d/device/vendor" 2>/dev/null | xargs) $(cat "$d/device/model" 2>/dev/null | xargs))  comandos: /dev/${sg:-?}"
    ls -l "/dev/$(basename "$d")" ${sg:+/dev/$sg} 2>/dev/null | sed 's/^/    /'
done
[ "$found" = 1 ] || echo "    Nenhum leitor de CD/DVD encontrado (confira o cabo SATA do leitor)."

echo
echo "Fase 5.8 instalada. Reinicie (para o grupo do leitor valer):  sudo reboot"
echo "Depois é só colocar o disco: ele aparece no topo de Jogos e em PS1/PS2."
