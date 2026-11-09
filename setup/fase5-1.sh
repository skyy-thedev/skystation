#!/bin/bash
# SkyStation: Fase 5.1
#   A. Boot 100% SkyStation: nada de logo ou texto do Arch Linux
#   B. Navegador próprio (WebKitGTK) para testes
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase5-1.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
step() { echo; echo "==> $*"; }
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

step "[1/5] Diagnóstico do boot atual (antes de mexer)"
install -m 755 "$SRC/setup/diag.sh" /usr/local/bin/skystation-diag
sed -i 's/\r$//' /usr/local/bin/skystation-diag
skystation-diag || true

step "[2/5] Identidade SkyStation (os-release, GRUB sem mensagens) + hook do pacman"
install -d /usr/local/share/skystation /etc/pacman.d/hooks
install -m 644 "$SRC/system/os-release" /usr/local/share/skystation/os-release
install -m 755 "$SRC/setup/marca.sh" /usr/local/bin/skystation-marca
install -m 644 "$SRC/system/pacman-hooks/skystation-marca.hook" /etc/pacman.d/hooks/skystation-marca.hook
sed -i 's/\r$//' /usr/local/share/skystation/os-release /usr/local/bin/skystation-marca /etc/pacman.d/hooks/skystation-marca.hook
skystation-marca

step "[3/5] Tema de boot reinstalado e fixado como padrão"
install -d /usr/share/plymouth/themes/skystation
install -m 644 "$SRC"/system/plymouth/skystation/* /usr/share/plymouth/themes/skystation/
sed -i 's/\r$//' /usr/share/plymouth/themes/skystation/*.plymouth /usr/share/plymouth/themes/skystation/*.script
install -d /etc/plymouth
printf '[Daemon]\nTheme=skystation\nShowDelay=0\nDeviceTimeout=8\n' >/etc/plymouth/plymouthd.conf
mkinitcpio -P

step "[4/5] Navegador: WebKitGTK 6 + GTK 4"
pacman -S --needed --noconfirm webkitgtk-6.0 gtk4 python-gobject

step "[5/5] Console atualizado (navegador entra no launcher)"
bash "$SRC/setup/atualizar.sh"
find /opt/skystation/games -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true

echo
echo "Fase 5.1 instalada. Reinicie:  sudo reboot"
echo "Depois do boot, rode  sudo skystation-diag  e me avise: confiro o tema no relatório."
