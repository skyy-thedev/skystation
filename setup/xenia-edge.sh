#!/bin/bash
# SkyStation 11.7: Xenia Edge, um segundo emulador de Xbox 360 ao lado do Canary.
# O Edge é um fork do Xenia Canary focado em Vulkan e no Linux (github.com/has207/xenia-edge).
# Fica em /opt/xenia-edge e só é usado pelos jogos que o sky-emu manda para ele (ex.: Dante's
# Inferno, que congela no Canary). O Canary em /opt/xenia continua sendo o padrão.
# Uso:  sudo bash /opt/skystation-src/setup/xenia-edge.sh        (o Atualizar do menu também chama)
set -uo pipefail
SRC="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"
DEST=/opt/xenia-edge

if [ -x "$DEST/xenia_edge" ] && [ "${1:-}" != "--atualizar" ]; then
    echo "    Xenia Edge já instalado (para atualizar: sudo bash $0 --atualizar)"
    exit 0
fi
TMP="$(mktemp -d /var/tmp/skystation-edge.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
source "$SRC/setup/appimage.sh"

URL="$(curl -fsSL "https://api.github.com/repos/has207/xenia-edge/releases?per_page=10" 2>/dev/null \
    | grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*"\(https[^"]*\)"/\1/' \
    | grep -i linux | grep -iE '\.tar\.(gz|xz|zst)$|\.zip$|\.7z$|\.AppImage$' | head -1 || true)"
if [ -z "$URL" ] || ! curl -fL --progress-bar -o "$TMP/edge.pkg" "$URL"; then
    echo "    AVISO: não achei a versão Linux do Xenia Edge agora (${URL:-sem link}); rode de novo mais tarde"
    exit 1
fi
anota "== xenia-edge: $(basename "$URL")"
mkdir -p "$TMP/x"
case "$URL" in
    *.AppImage) cp "$TMP/edge.pkg" "$TMP/x/edge.AppImage" ;;
    *) bsdtar -xf "$TMP/edge.pkg" -C "$TMP/x" 2>/dev/null || tar -xf "$TMP/edge.pkg" -C "$TMP/x" ;;
esac
APPI="$(find "$TMP/x" -type f -iname '*.AppImage' | head -1)"
if [ -n "$APPI" ]; then
    mv "$APPI" "$TMP/edge.AppImage"
    instalar_appimage "$TMP/edge.AppImage" "$TMP/x/app" || echo "    AVISO: não consegui extrair o AppImage do Xenia Edge"
fi
# o programa: o maior executável (ELF) com "xenia" no nome, ou o AppRun
BIN=""
while IFS= read -r f; do
    [ "$(head -c 4 "$f" | tr -d '\0' | cut -c2-4)" = "ELF" ] && { BIN="$f"; break; }
done < <(find "$TMP/x" -type f -iname '*xenia*' -printf '%s\t%p\n' | sort -rn | cut -f2-)
[ -z "$BIN" ] && [ -f "$TMP/x/app/AppRun" ] && BIN="$TMP/x/app/AppRun"
if [ -z "$BIN" ]; then
    echo "    AVISO: baixei $(basename "$URL") mas não achei o programa. Conteúdo do pacote:"
    find "$TMP/x" -maxdepth 2 | sed "s|$TMP/x|      |" | head -15
    copia_log; exit 1
fi
# guarda a configuração do Edge que já existir (opções por jogo, cache) ao atualizar
GUARDA=""
[ -d "$DEST" ] && { GUARDA="$TMP/guarda"; mkdir -p "$GUARDA"; cp -a "$DEST"/*.toml "$DEST/config" "$GUARDA/" 2>/dev/null; }
rm -rf "$DEST"
mv "$(dirname "$BIN")" "$DEST"
chmod +x "$DEST/$(basename "$BIN")"
[ "$(basename "$BIN")" = xenia_edge ] || ln -sf "$(basename "$BIN")" "$DEST/xenia_edge"
[ -n "$GUARDA" ] && cp -a "$GUARDA"/. "$DEST/" 2>/dev/null
# como o Canary: configuração e cache ao lado do programa, numa pasta do jogador
touch "$DEST/portable.txt"; chown -R "$USER_NAME:$USER_NAME" "$DEST"
anota "xenia-edge instalado em $DEST ($(basename "$BIN"))"; copia_log
echo "    Xenia Edge instalado em $DEST ($(basename "$URL"))"
