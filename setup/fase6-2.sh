#!/bin/bash
# SkyStation: Fase 6.2 — QR code na Central web, celular como teclado, terminal secreto,
# tela Armazenamento, gestos no touchpad do DS4, SNES e N64.
# Uso:  sudo bash /opt/skystation-src/setup/fase6-2.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_NAME="sky"; UHOME="/home/$USER_NAME"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

echo "==> [1/3] Pacotes: python-qrcode (QR), wtype (celular como teclado), foot (terminal)"
for p in python-qrcode wtype foot unzip; do
    pacman -Q "$p" >/dev/null 2>&1 && { echo "    $p ok"; continue; }
    if pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 || pacman -Syu --needed --noconfirm "$p" >/dev/null 2>&1; then
        echo "    $p instalado"
    else
        echo "    AVISO: não consegui instalar $p agora (o resto continua funcionando)"
    fi
done

echo "==> [2/3] Emuladores: SNES (Snes9x) e N64 (Mupen64Plus-Next), do buildbot oficial do libretro"
install -d /opt/skystation/emu/cores
TMP="$(mktemp -d)"
for core in snes9x mupen64plus_next; do
    if curl -fsSL -o "$TMP/$core.zip" "https://buildbot.libretro.com/nightly/linux/x86_64/latest/${core}_libretro.so.zip" \
        && unzip -o -q "$TMP/$core.zip" -d "$TMP"; then
        install -m 644 "$TMP/${core}_libretro.so" "/opt/skystation/emu/cores/${core}_libretro.so"
        echo "    $core ok"
    else
        echo "    AVISO: não consegui baixar o core $core (confira a internet e rode de novo)"
    fi
done
for s in snes n64; do
    for d in roms/$s roms/$s/covers saves/$s states/$s; do
        install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d"
    done
done

echo "==> [3/3] Console"
bash "$SRC/setup/atualizar.sh"
rm -rf "$TMP"
find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
echo
echo "Fase 6.2 instalada. Reinicie a interface (Energia → Reiniciar a interface) ou o console."
