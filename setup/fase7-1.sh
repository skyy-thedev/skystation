#!/bin/bash
# SkyStation: Fase 7.1 — mais consoles: GameCube, Wii, Nintendo DS, 3DS, Game Boy/Color/Advance,
# NES, Mega Drive (cores do RetroArch) e Xbox 360 (Xenia Canary para Linux, experimental).
# Uso:  sudo bash /opt/skystation-src/setup/fase7-1.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"
UHOME="/home/$USER_NAME"
BB="https://buildbot.libretro.com"
pacman -Q unzip >/dev/null 2>&1 || pacman -S --needed --noconfirm unzip >/dev/null 2>&1 || true
install -d /opt/skystation/emu/cores
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# core <nome do sistema> <candidatos…>: instala o primeiro que existir no buildbot oficial do libretro
core() {
    local nome="$1" c; shift
    for c in "$@"; do
        [ -f "/opt/skystation/emu/cores/${c}_libretro.so" ] && { echo "    $nome: ok ($c)"; return 0; }
    done
    for c in "$@"; do
        if curl -fsSL -o "$TMP/c.zip" "$BB/nightly/linux/x86_64/latest/${c}_libretro.so.zip" 2>/dev/null \
            && unzip -o -q "$TMP/c.zip" -d "$TMP" && [ -f "$TMP/${c}_libretro.so" ]; then
            install -m 644 "$TMP/${c}_libretro.so" "/opt/skystation/emu/cores/${c}_libretro.so"
            echo "    $nome: instalado ($c)"; return 0
        fi
    done
    echo "    AVISO: não consegui baixar o emulador de $nome (confira a internet e rode de novo)"
}

echo "==> [1/4] Emuladores (cores do RetroArch)"
core "GameCube e Wii" dolphin
core "Nintendo DS" melondsds melonds desmume
core "Nintendo 3DS" azahar citra
core "Game Boy Advance" mgba
core "Game Boy / Color" gambatte
core "NES" nestopia fceumm
core "Mega Drive" genesis_plus_gx

echo "==> [2/4] Pastas e arquivos de apoio"
for s in gc wii x360 nds 3ds gba gb nes md; do
    for d in "roms/$s" "roms/$s/covers" "saves/$s" "states/$s"; do
        install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d" 2>/dev/null || true
    done
done
for d in bios/dolphin bios/nds bios/3ds; do install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d"; done
if [ ! -d "$UHOME/skystation/bios/dolphin/dolphin-emu/Sys" ]; then
    if curl -fsSL -o "$TMP/dolphin.zip" "$BB/assets/system/Dolphin.zip" && unzip -o -q "$TMP/dolphin.zip" -d "$UHOME/skystation/bios/dolphin"; then
        chown -R "$USER_NAME:$USER_NAME" "$UHOME/skystation/bios/dolphin"; echo "    apoio do GameCube/Wii ok"
    else
        echo "    AVISO: sem os arquivos de apoio do GameCube/Wii (alguns jogos podem não abrir)"
    fi
else
    echo "    apoio do GameCube/Wii já instalado"
fi

echo "==> [3/4] Xbox 360 (Xenia Canary para Linux — experimental, só em PC com 6+ threads)"
if [ ! -x /opt/xenia/xenia_canary ]; then
    URL=""
    for repo in xenia-canary/xenia-canary xenia-canary/xenia-canary-releases; do   # o mais novo que tiver pacote Linux
        URL="$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=15" 2>/dev/null \
            | grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*"\(https[^"]*\)"/\1/' \
            | grep -i linux | grep -iE '\.tar\.(gz|xz|zst)$|\.zip$|\.7z$|\.AppImage$' | head -1 || true)"
        [ -n "$URL" ] && break
    done
    if [ -n "$URL" ] && curl -fL --progress-bar -o "$TMP/xenia.pkg" "$URL"; then
        rm -rf /opt/xenia "$TMP/x"; mkdir -p "$TMP/x"
        case "$URL" in
            *.AppImage) cp "$TMP/xenia.pkg" "$TMP/x/xenia.AppImage" ;;
            *) bsdtar -xf "$TMP/xenia.pkg" -C "$TMP/x" 2>/dev/null || tar -xf "$TMP/xenia.pkg" -C "$TMP/x" ;;
        esac
        # AppImage (solto ou dentro do pacote): extrai, porque o console não usa FUSE
        APPI="$(find "$TMP/x" -type f -iname '*.AppImage' | head -1)"
        if [ -n "$APPI" ]; then
            chmod +x "$APPI"; (cd "$TMP" && "$APPI" --appimage-extract >/dev/null 2>&1) && rm -rf "$TMP/x" && mv "$TMP/squashfs-root" "$TMP/x"
        fi
        # o programa: o maior arquivo executável (ELF) com "xenia" no nome, ou o AppRun
        BIN=""
        while IFS= read -r f; do
            [ "$(head -c 4 "$f" | tr -d '\0' | cut -c2-4)" = "ELF" ] && { BIN="$f"; break; }
        done < <(find "$TMP/x" -type f -iname '*xenia*' -printf '%s\t%p\n' | sort -rn | cut -f2-)
        [ -z "$BIN" ] && [ -f "$TMP/x/AppRun" ] && BIN="$TMP/x/AppRun"
        if [ -n "$BIN" ]; then
            mv "$(dirname "$BIN")" /opt/xenia
            chmod +x "/opt/xenia/$(basename "$BIN")"
            [ "$(basename "$BIN")" = xenia_canary ] || ln -sf "$(basename "$BIN")" /opt/xenia/xenia_canary
            # o Xenia guarda configuração e cache ao lado do programa: a pasta precisa ser do jogador
            touch /opt/xenia/portable.txt; chown -R "$USER_NAME:$USER_NAME" /opt/xenia
            echo "    Xenia instalado em /opt/xenia ($(basename "$URL"))"
        else
            echo "    AVISO: baixei $(basename "$URL") mas não achei o programa. Conteúdo do pacote:"
            find "$TMP/x" -maxdepth 2 | sed "s|$TMP/x|      |" | head -15
        fi
    else
        echo "    AVISO: não achei a versão Linux do Xenia Canary agora (${URL:-sem link}); rode de novo mais tarde"
    fi
else
    echo "    Xenia já instalado (para atualizar: sudo rm -rf /opt/xenia e rode esta fase de novo)"
fi

echo "==> [4/4] Console"
bash "$SRC/setup/atualizar.sh"
echo
echo "Fase 7.1 instalada. Reinicie a interface (Energia → Reiniciar a interface)."
echo "Jogos: Central web → Enviar → escolha o sistema. As categorias aparecem quando houver jogos."
