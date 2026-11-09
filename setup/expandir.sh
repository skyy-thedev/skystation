#!/bin/bash
# SkyStation: expande o sistema para ocupar toda a mídia (cartão SD, pendrive ou SSD).
# Rodar uma vez, no primeiro boot depois de clonar:  sudo skystation-expandir
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }

ROOT_PART="$(findmnt -n -o SOURCE /)"
DISK="/dev/$(lsblk -no PKNAME "$ROOT_PART")"
LAST="$(lsblk -lnpo NAME,TYPE "$DISK" | awk '$2=="part"{p=$1} END{print p}')"

echo "Disco: $DISK   |   partição do sistema: $ROOT_PART   |   última partição: $LAST"
lsblk "$DISK"

if [ "$LAST" != "$ROOT_PART" ]; then
    MP="$(findmnt -n -o TARGET "$LAST" || true)"
    echo "A última partição não é a do sistema (é ${MP:-sem montagem}). Vou expandir ela."
fi
FSTYPE="$(lsblk -no FSTYPE "$LAST")"
[ "$FSTYPE" = "ext4" ] || { echo "Partição $LAST é $FSTYPE; só sei expandir ext4."; exit 1; }

# imagem clonada p/ midia de outro tamanho: move a copia de seguranca do GPT p/ o fim real do disco
if command -v sgdisk >/dev/null && [ "$(lsblk -no PTTYPE "$DISK")" = "gpt" ]; then
    sgdisk -e "$DISK" >/dev/null && partprobe "$DISK" 2>/dev/null || true
fi

NUM="$(cat "/sys/class/block/$(basename "$LAST")/partition")"
growpart "$DISK" "$NUM" || echo "(growpart: nada a expandir ou já expandida)"
resize2fs "$LAST"
echo
df -h /
echo "Pronto: o SkyStation agora usa a mídia inteira."
