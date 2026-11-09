#!/bin/bash
# SkyStation: Fase 5.3. Boot com o logo do SkyStation e sem texto.
# O archinstall montou o boot como UKI (kernel + initramfs + linha de comando num só .efi,
# aberto pelo GRUB). Aqui a linha de comando vem de /etc/kernel/cmdline e o logo inicial
# (o do Arch) vem do preset do mkinitcpio. Esta fase troca os dois e recria o .efi.
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase5-3.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

echo "==> Logo de boot do SkyStation"
install -d /usr/local/share/skystation
install -m 644 "$SRC/system/splash.bmp" /usr/local/share/skystation/splash.bmp

echo "==> Comandos atualizados (skystation-marca, skystation-diag)"
install -m 755 "$SRC/setup/marca.sh" /usr/local/bin/skystation-marca
install -m 755 "$SRC/setup/diag.sh" /usr/local/bin/skystation-diag
sed -i 's/\r$//' /usr/local/bin/skystation-marca /usr/local/bin/skystation-diag

echo "==> Aplicando: linha de comando silenciosa + logo + recriar UKI"
cp -n /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux.preset.antes-fase5-3 2>/dev/null || true
[ -f /etc/kernel/cmdline ] && cp -n /etc/kernel/cmdline /etc/kernel/cmdline.antes-fase5-3 || true
skystation-marca

echo
echo "Pronto. Reinicie:  sudo reboot"
echo "Depois:  sudo skystation-diag   (eu confiro que a linha de comando tem 'quiet splash')"
