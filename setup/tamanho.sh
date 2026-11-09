#!/bin/bash
# skystation: mede o espaco usado p/ caber num pendrive menor
OUT=/mnt/skystation/diag-tamanho.txt
{
echo "== lsblk"; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
echo; echo "== df"; df -h / /boot /efi 2>/dev/null
echo; echo "== maiores pastas"
du -xsh /var/cache/pacman/pkg /home/sky/skystation/roms /home/sky/skystation/bios /home/sky/.wine* /home/sky/skystation/wine* /opt/* /usr/lib /usr/share /var/log /home/sky/.cache /root 2>/dev/null | sort -rh
echo; echo "== swap"; swapon --show
} > "$OUT" 2>&1
sed -i 's/\r$//' "$OUT"
echo "Pronto: $OUT"
