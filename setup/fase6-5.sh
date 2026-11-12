#!/bin/bash
# SkyStation: Fase 6.5 — PSP (PPSSPP), desempenho automático por jogo no PS2, conferir cópia.
# Uso:  sudo bash /opt/skystation-src/setup/fase6-5.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_NAME="sky"; UHOME="/home/$USER_NAME"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

echo "==> [1/3] Console"
bash "$SRC/setup/atualizar.sh"

echo "==> [2/3] Emulador de PSP (core PPSSPP do libretro)"
pacman -Q unzip >/dev/null 2>&1 || pacman -S --needed --noconfirm unzip >/dev/null 2>&1 || true
install -d /opt/skystation/emu/cores
TMP="$(mktemp -d)"
if curl -fsSL -o "$TMP/core.zip" "https://buildbot.libretro.com/nightly/linux/x86_64/latest/ppsspp_libretro.so.zip" \
    && unzip -o -q "$TMP/core.zip" -d "$TMP"; then
    install -m 644 "$TMP/ppsspp_libretro.so" /opt/skystation/emu/cores/ppsspp_libretro.so
    echo "    core ok"
else
    echo "    AVISO: não consegui baixar o core do PSP (confira a internet e rode de novo)"
fi

echo "==> [3/3] Arquivos de apoio do PSP (fontes e dados do PPSSPP)"
for d in roms/psp roms/psp/covers saves/psp states/psp bios/psp; do
    install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d"
done
if [ ! -d "$UHOME/skystation/bios/psp/PPSSPP" ]; then
    if curl -fsSL -o "$TMP/assets.zip" "https://buildbot.libretro.com/assets/system/PPSSPP.zip" \
        && unzip -o -q "$TMP/assets.zip" -d "$UHOME/skystation/bios/psp"; then
        chown -R "$USER_NAME:$USER_NAME" "$UHOME/skystation/bios/psp"
        echo "    apoio ok"
    else
        echo "    AVISO: sem os arquivos de apoio. Os jogos abrem, mas alguns textos podem não aparecer."
    fi
else
    echo "    apoio já instalado"
fi
rm -rf "$TMP"
echo
echo "Fase 6.5 instalada. Reinicie a interface (Energia → Reiniciar a interface)."
echo "Jogos de PSP (.iso ou .cso): Central web → Enviar → PSP."
