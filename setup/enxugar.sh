#!/bin/bash
# SkyStation: enxuga o sistema antes de gerar a imagem pequena (pendrive de 8 GB).
# Rodar como root na VM:  bash /mnt/skystation/setup/enxugar.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Rode como root."; exit 1; }

echo "== instalando gptfdisk (usado pelo skystation-expandir)"
pacman -S --needed --noconfirm gptfdisk

echo "== atualizando o skystation-expandir"
sed 's/\r$//' /mnt/skystation/setup/expandir.sh > /usr/local/bin/skystation-expandir
chmod 755 /usr/local/bin/skystation-expandir

echo "== limpando cache do pacman, logs e caches"
rm -rf /var/cache/pacman/pkg/*   # -Scc com --noconfirm responde "N" e nao apaga nada
journalctl --vacuum-size=10M || true
rm -rf /home/sky/.cache/* /root/.cache 2>/dev/null || true

echo "== reserva do ext4: 5% -> 1%"
tune2fs -m 1 "$(findmnt -n -o SOURCE /)"

echo
df -h /
echo "Pronto. Agora: poweroff, e siga a Parte B (ISO do Arch)."
