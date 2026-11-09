#!/bin/bash
# SkyStation: Fase 5.2
#   A. Boot pelo systemd-boot (o que o archinstall instalou): menu oculto, nome SkyStation,
#      kernel silencioso com a tela de boot do SkyStation
#   B. Navegador: codecs de vídeo (YouTube) via GStreamer
#   C. Sky Snake + PS1 aceitando .iso/.img/.bin
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase5-2.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
step() { echo; echo "==> $*"; }
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

step "[1/4] Identidade e boot silencioso (systemd-boot)"
install -m 755 "$SRC/setup/marca.sh" /usr/local/bin/skystation-marca
install -m 755 "$SRC/setup/diag.sh" /usr/local/bin/skystation-diag
sed -i 's/\r$//' /usr/local/bin/skystation-marca /usr/local/bin/skystation-diag
skystation-marca

step "[2/4] Codecs de vídeo para o navegador (H.264, VP9, AV1, AAC, Opus)"
pacman -S --needed --noconfirm gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav

step "[3/4] Console atualizado (Sky Snake, navegador, PS1)"
bash "$SRC/setup/atualizar.sh"
find /opt/skystation/games -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true

step "[4/4] Pastas de ROMs"
install -d -o sky -g sky /home/sky/skystation/roms/ps1 /home/sky/skystation/roms/ps2

echo
echo "Fase 5.2 instalada. Reinicie:  sudo reboot"
echo "Depois do boot:  sudo skystation-diag   (para eu conferir o boot)"
