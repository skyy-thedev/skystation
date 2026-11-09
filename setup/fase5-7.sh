#!/bin/bash
# SkyStation: Fase 5.7 — som de ligar, modo de espera com "ligar pelo controle",
# receber jogos pelo Wi-Fi, mover jogos entre o console e o SKYROMS, espaço total.
# Uso:  sudo bash /opt/skystation-src/setup/fase5-7.sh      (na VM: /mnt/skystation/setup/fase5-7.sh)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

echo "==> [1/4] Pacote: alsa-utils (tocar o som de ligar antes do console abrir)"
if ! pacman -S --needed --noconfirm alsa-utils; then
    free_mb="$(df -m --output=avail / | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -ge 1500 ]; then
        pacman -Syu --needed --noconfirm alsa-utils || echo "    Não consegui instalar o alsa-utils agora."
    else
        echo "    Pouco espaço para atualizar o sistema: o som de ligar fica para depois."
    fi
fi

echo "==> [2/4] Console (launcher, sky-receber, sky-jogos)"
bash "$SRC/setup/atualizar.sh"

echo "==> [3/4] Som de ligar"
sed 's/\r$//' "$SRC/setup/som-ligar.sh" >/usr/local/bin/skystation-som-ligar
chmod 755 /usr/local/bin/skystation-som-ligar
cat >/etc/systemd/system/skystation-som-ligar.service <<'UNIT'
[Unit]
Description=SkyStation: som de ligar
After=sound.target alsa-restore.service
Wants=sound.target

[Service]
Type=exec
ExecStart=/usr/local/bin/skystation-som-ligar

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable skystation-som-ligar.service >/dev/null 2>&1 || true

echo "==> [4/4] Ligar pelo controle (modo de espera)"
/usr/local/bin/skystation-energia || true
systemctl enable --now skystation-energia.timer >/dev/null 2>&1 || true

find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
echo
echo "Fase 5.7 instalada. Reinicie para ouvir o som de ligar:  sudo reboot"
