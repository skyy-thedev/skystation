#!/bin/bash
# SkyStation: Fase 6.3 — perfis de jogador, troféus, YouTube para TV e Moonlight (jogos do PC).
# Uso:  sudo bash /opt/skystation-src/setup/fase6-3.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

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

echo "==> [1/3] Vídeo: codecs para o YouTube e decodificação pela placa de vídeo (Moonlight)"
instalar gst-plugins-good gst-plugins-bad gst-libav libva-intel-driver

echo "==> [2/3] Moonlight"
if ! command -v moonlight >/dev/null 2>&1 && ! command -v moonlight-qt >/dev/null 2>&1 && [ ! -x /opt/moonlight/AppRun ]; then
    if pacman -S --needed --noconfirm moonlight-qt >/dev/null 2>&1; then
        echo "    moonlight-qt instalado pelo pacman"
    else
        echo "    pacote não disponível: baixando o AppImage oficial do GitHub"
        URL="$(curl -fsSL https://api.github.com/repos/moonlight-stream/moonlight-qt/releases/latest \
            | grep -o '"browser_download_url": *"[^"]*x86_64\.AppImage"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
        TMP="$(mktemp -d)"
        if [ -n "$URL" ] && curl -fsSL -o "$TMP/moonlight.AppImage" "$URL"; then
            chmod +x "$TMP/moonlight.AppImage"
            (cd "$TMP" && ./moonlight.AppImage --appimage-extract >/dev/null 2>&1)
            rm -rf /opt/moonlight && mv "$TMP/squashfs-root" /opt/moonlight && chmod -R a+rX /opt/moonlight
            echo "    Moonlight instalado em /opt/moonlight"
        else
            echo "    AVISO: não consegui baixar o Moonlight (confira a internet e rode de novo)"
        fi
        rm -rf "$TMP"
    fi
else
    echo "    Moonlight já instalado"
fi

echo "==> [3/3] Console (perfis, troféus, apps)"
bash "$SRC/setup/atualizar.sh"
find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
echo
echo "Fase 6.3 instalada. Reinicie a interface (Energia → Reiniciar a interface)."
echo "No PC, para o Moonlight: instale o Sunshine (da LizardByte, gratuito) e deixe-o aberto."
