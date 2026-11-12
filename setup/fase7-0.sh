#!/bin/bash
# SkyStation: Fase 7.0 — Central web em segundo plano, som de ligar na TV e PlayStation 3 (RPCS3).
# O PS3 só roda em PC forte (6+ threads): a ideia é dar boot com o pendrive num notebook/PC melhor.
# Por isso esta fase também deixa o pendrive pronto para ligar em outro computador (AMD ou Intel).
# Uso:  sudo bash /opt/skystation-src/setup/fase7-0.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"
UHOME="/home/$USER_NAME"

instalar() {
    for p in "$@"; do
        pacman -Q "$p" >/dev/null 2>&1 && { echo "    $p ok"; continue; }
        if pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 || pacman -Syu --needed --noconfirm "$p" >/dev/null 2>&1; then
            echo "    $p instalado"
        else
            echo "    AVISO: não consegui instalar $p agora"
        fi
    done
}

echo "==> [1/6] Drivers para outros PCs (vídeo AMD/Intel, Wi-Fi, microcódigo)"
instalar linux-firmware mesa vulkan-radeon vulkan-intel vulkan-icd-loader amd-ucode intel-ucode alsa-utils

echo "==> [2/6] Boot em qualquer PC"
mudou=0
for f in /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf; do
    if [ -f "$f" ] && grep -qE '^HOOKS=.*\bautodetect\b' "$f"; then
        sed -i -E '/^HOOKS=/ s/ ?\bautodetect\b//' "$f"; mudou=1
    fi
done
if [ "$mudou" = 1 ]; then
    free_mb="$(df -m --output=avail /boot | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -ge 150 ]; then
        echo "    recriando a imagem de boot com drivers para qualquer PC…"
        mkinitcpio -P >/tmp/skystation-mkinitcpio.log 2>&1 || echo "    AVISO: mkinitcpio falhou (veja /tmp/skystation-mkinitcpio.log)"
    else
        echo "    AVISO: /boot com pouco espaço (${free_mb} MB): não recriei a imagem de boot"
    fi
else
    echo "    imagem de boot já é genérica"
fi
# Wi-Fi: uma rede salva "presa" ao nome da placa deste PC não conecta em outro
n=0
for f in /etc/NetworkManager/system-connections/*.nmconnection; do
    [ -f "$f" ] && grep -q '^interface-name=' "$f" && { sed -i '/^interface-name=/d' "$f"; n=$((n+1)); }
done
[ "$n" -gt 0 ] && { echo "    $n rede(s) Wi-Fi liberadas para qualquer placa"; nmcli connection reload 2>/dev/null || true; }

echo "==> [3/6] Controles Sony direto no emulador (hidraw) e limite de arquivos abertos"
cat >/etc/udev/rules.d/72-skystation-controles.rules <<'RULES'
# SkyStation: o RPCS3 fala direto com DualShock 3/4 e DualSense (vibração, sensores) pelo hidraw
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0268|05c4|09cc|0ba0|0ce6|0df2", MODE="0660", GROUP="input", TAG+="uaccess"
KERNEL=="hidraw*", KERNELS=="*054C:0268*|*054C:05C4*|*054C:09CC*|*054C:0CE6*|*054C:0DF2*", MODE="0660", GROUP="input", TAG+="uaccess"
RULES
usermod -aG input "$USER_NAME" || true
udevadm control --reload-rules || true
udevadm trigger --subsystem-match=hidraw 2>/dev/null || true
install -d /etc/security/limits.d
printf '%s soft nofile 65536\n%s hard nofile 524288\n' "$USER_NAME" "$USER_NAME" >/etc/security/limits.d/skystation.conf

echo "==> [4/6] Emulador de PS3 (RPCS3, AppImage oficial extraído)"
if [ ! -x /opt/rpcs3/AppRun ]; then
    free_mb="$(df -m --output=avail / | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -lt 1200 ]; then
        echo "    AVISO: pouco espaço (${free_mb} MB) para o RPCS3; libere espaço e rode de novo"
    else
        TMP="$(mktemp -d)"
        URL="$(curl -fsSL https://api.github.com/repos/RPCS3/rpcs3-binaries-linux/releases/latest 2>/dev/null \
            | grep -o '"browser_download_url": *"[^"]*_linux64\.AppImage"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/' || true)"
        [ -n "$URL" ] || URL="https://rpcs3.net/latest-appimage"
        if curl -fL --progress-bar -o "$TMP/rpcs3.AppImage" "$URL" && [ "$(stat -c %s "$TMP/rpcs3.AppImage")" -gt 20000000 ]; then
            chmod +x "$TMP/rpcs3.AppImage"
            (cd "$TMP" && ./rpcs3.AppImage --appimage-extract >/dev/null 2>&1)
            rm -rf /opt/rpcs3 && mv "$TMP/squashfs-root" /opt/rpcs3 && chmod -R a+rX /opt/rpcs3
            echo "    RPCS3 instalado em /opt/rpcs3"
        else
            echo "    AVISO: não consegui baixar o RPCS3 (confira a internet e rode de novo)"
        fi
        rm -rf "$TMP"
    fi
else
    echo "    RPCS3 já instalado (para atualizar: sudo rm -rf /opt/rpcs3 e rode esta fase de novo)"
fi

echo "==> [5/6] Pastas do PS3"
for d in roms/ps3 bios/ps3; do install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d"; done

echo "==> [6/6] Console (Central web em segundo plano, som de ligar na TV, categoria PS3)"
bash "$SRC/setup/atualizar.sh"
find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
echo
echo "Fase 7.0 instalada. Reinicie:  sudo reboot"
echo "PS3: 1) envie o PS3UPDAT.PUP (site oficial da PlayStation) pela Central web → Sistema: Firmware do PS3"
echo "     2) jogos (pasta do disco ou .iso) em ~/skystation/roms/ps3 ou SKYROMS/ps3"
echo "     3) dê boot com o pendrive no PC forte (desligue o Secure Boot na BIOS dele) e abra a categoria PS3"
