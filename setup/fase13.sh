#!/bin/bash
# SkyStation: Fase 13 — mais consoles:
#   Dreamcast (Flycast) e Saturn (Beetle Saturn; YabaSanshiro quando não há BIOS)   -> cores do RetroArch
#   Wii U (Cemu), PS Vita (Vita3K), Xbox original (xemu)  -> core do RetroArch se existir; senão o programa oficial
#   PS4 (shadPS4, experimental)                            -> programa oficial (AppImage)
#   Switch 1 (só testes)                                   -> AppImage que VOCÊ baixa no site oficial (Eden ou
#                                                             Citron) e deixa em SKYROMS/emuladores/
# Uso:  sudo bash /opt/skystation-src/setup/fase13.sh
# BIOS, chaves e firmwares não vêm junto (são da Sony/Microsoft/Nintendo/Sega): veja o fim deste script.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"
UHOME="/home/$USER_NAME"
BB="https://buildbot.libretro.com"
CORES=/opt/skystation/emu/cores
for p in unzip libarchive; do pacman -Q "$p" >/dev/null 2>&1 || pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 || true; done
install -d "$CORES"
TMP="$(mktemp -d /var/tmp/skystation-fase13.XXXXXX)"; trap 'rm -rf "$TMP"' EXIT
source "$SRC/setup/appimage.sh"
anota "== fase13"

# core <nome do sistema> <candidatos…>: instala o primeiro que existir no buildbot oficial do libretro.
# Devolve 0 se algum ficou instalado (para decidir se precisa do programa separado).
core() {
    local nome="$1" c; shift
    for c in "$@"; do
        [ -f "$CORES/${c}_libretro.so" ] && { echo "    $nome: ok ($c)"; return 0; }
    done
    for c in "$@"; do
        if curl -fsSL -o "$TMP/c.zip" "$BB/nightly/linux/x86_64/latest/${c}_libretro.so.zip" 2>/dev/null \
            && unzip -o -q "$TMP/c.zip" -d "$TMP" && [ -f "$TMP/${c}_libretro.so" ]; then
            install -m 644 "$TMP/${c}_libretro.so" "$CORES/${c}_libretro.so"
            rm -f "$TMP/${c}_libretro.so" "$TMP/c.zip"
            echo "    $nome: instalado ($c)"; return 0
        fi
    done
    echo "    $nome: sem core do RetroArch"
    return 1
}

# link_github <dono/repo> <filtro> [preferido]: link do pacote Linux mais novo das últimas releases.
link_github() {
    local todos
    todos="$(curl -fsSL "https://api.github.com/repos/$1/releases?per_page=10" 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*"\(https[^"]*\)"/\1/' \
        | grep -iE "$2" | grep -viE 'debug|dbg|symbols|\.sha256|\.zsync|aarch64|arm64' || true)"
    if [ -n "${3:-}" ] && printf '%s\n' "$todos" | grep -qiE "$3"; then
        printf '%s\n' "$todos" | grep -iE "$3" | head -1
    else
        printf '%s\n' "$todos" | head -1
    fi
}

# programa <nome> <pasta de destino> <dono/repo> <filtro> [preferido]: baixa e instala um AppImage
# (solto ou dentro de .zip/.tar) com o instalar_appimage da Fase 7 (extrai; o console não usa FUSE).
programa() {
    local nome="$1" dest="$2" url appi
    if [ -x "$dest/AppRun" ]; then echo "    $nome: já instalado em $dest"; return 0; fi
    url="$(link_github "$3" "$4" "${5:-}")"
    [ -n "$url" ] || { echo "    AVISO: não achei a versão Linux do $nome agora (rode de novo mais tarde)"; return 1; }
    echo "    baixando $nome ($(basename "$url"))"
    rm -rf "$TMP/p"; mkdir -p "$TMP/p"
    curl -fL --progress-bar -o "$TMP/p/pacote" "$url" || { echo "    AVISO: o download do $nome falhou"; return 1; }
    case "$url" in
        *.AppImage|*.appimage) mv "$TMP/p/pacote" "$TMP/p/programa.AppImage" ;;
        *) (cd "$TMP/p" && bsdtar -xf pacote 2>/dev/null || unzip -o -q pacote 2>/dev/null || tar -xf pacote) || true ;;
    esac
    appi="$(find "$TMP/p" -type f -iname '*.AppImage' | head -1)"
    if [ -z "$appi" ]; then
        echo "    AVISO: o pacote do $nome não tem AppImage. Conteúdo:"; find "$TMP/p" -maxdepth 2 | sed "s|$TMP/p|      |" | head -10
        return 1
    fi
    anota "fase13: $nome <- $(basename "$url")"
    if instalar_appimage "$appi" "$dest"; then echo "    $nome instalado em $dest"
    else echo "    AVISO: não consegui instalar o $nome (log: $LOG_INST)"; return 1; fi
}

echo "==> [1/5] Dreamcast e Saturn (cores do RetroArch)"
core "Dreamcast" flycast || true
core "Saturn (com BIOS)" mednafen_saturn || true
core "Saturn (sem BIOS)" yabasanshiro || true

echo "==> [2/5] Wii U, PS Vita e Xbox original"
core "Wii U" cemu || programa "Cemu (Wii U)" /opt/cemu cemu-project/Cemu 'x86_64\.AppImage$' || true
core "PS Vita" vita3k || programa "Vita3K (PS Vita)" /opt/vita3k Vita3K/Vita3K '\.AppImage$' 'x86_64' || true
core "Xbox original" xemu || programa "xemu (Xbox)" /opt/xemu xemu-project/xemu 'x86_64\.AppImage$' || true

echo "==> [3/5] PS4 (shadPS4, experimental)"
programa "shadPS4 (PS4)" /opt/shadps4 shadps4-emu/shadPS4 'linux.*(\.zip|\.AppImage|\.tar\.gz)$' 'sdl' || true

echo "==> [4/5] Switch 1 (só testes)"
# Os emuladores de Switch vivem fugindo de pedidos de remoção da Nintendo e há sites FALSOS com vírus
# imitando os oficiais. Por isso o SkyStation não baixa nada sozinho: você baixa o AppImage do site
# oficial do Eden (ou do Citron) no PC e coloca em SKYROMS/emuladores/.
SWITCH_IMG="$(find /mnt/skyroms/emuladores -maxdepth 1 -type f -iregex '.*\(eden\|citron\).*\.appimage' 2>/dev/null | sort -r | head -1 || true)"
if [ -n "$SWITCH_IMG" ]; then
    cp "$SWITCH_IMG" "$TMP/switch.AppImage"
    anota "fase13: Switch <- $(basename "$SWITCH_IMG")"
    if instalar_appimage "$TMP/switch.AppImage" /opt/switch; then
        basename "$SWITCH_IMG" >/opt/switch/ORIGEM
        echo "    Switch: $(basename "$SWITCH_IMG") instalado em /opt/switch"
    fi
elif [ -x /opt/switch/AppRun ]; then
    echo "    Switch: já instalado ($(cat /opt/switch/ORIGEM 2>/dev/null))"
else
    echo "    Switch: pulei. Baixe o AppImage do Eden (ou do Citron) no site oficial, coloque em"
    echo "            SKYROMS/emuladores/ e rode esta fase de novo."
fi

echo "==> [5/5] Pastas e console"
for s in ps4 switch wiiu vita xbox dc saturn; do
    for d in "roms/$s" "roms/$s/covers" "saves/$s" "states/$s" "bios/$s"; do
        install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d" 2>/dev/null || true
    done
done
if [ -d /mnt/skyroms ] && [ -w /mnt/skyroms ]; then
    for s in ps4 switch wiiu vita xbox dc saturn; do mkdir -p "/mnt/skyroms/$s" "/mnt/skyroms/bios/$s" 2>/dev/null || true; done
    mkdir -p /mnt/skyroms/emuladores 2>/dev/null || true
fi
bash "$SRC/setup/atualizar.sh"
copia_log

cat <<'TXT'

Fase 13 instalada. Reinicie a interface (Energia → Reiniciar a interface).
Jogos em SKYROMS/<sistema>/ (ps4, switch, wiiu, vita, xbox, dc, saturn). As categorias aparecem quando houver jogos.
Arquivos que você precisa ter (do seu console), em SKYROMS/bios/<sistema>/:
  dc      nada obrigatório (o Flycast tem BIOS própria); com dc_boot.bin + dc_flash.bin fica mais compatível
  saturn  sega_101.bin (Japão) ou mpr-17933.bin (EUA/Europa); sem eles usa o YabaSanshiro
  xbox    mcpx_1.0.bin, a BIOS (ex.: Complex_4627.bin) e o HD xbox_hdd.qcow2 (o do site do xemu)
  vita    firmware PSP2UPDAT.PUP (do site da Sony) — jogos em .vpk
  wiiu    keys.txt só para .wud/.wux criptografados; .wua e pastas com code/*.rpx abrem direto
  switch  prod.keys (+ title.keys) e a pasta firmware/ com os .nca — teste apenas
  ps4     os módulos do sistema são opcionais; o jogo é a pasta com eboot.bin (CUSAxxxxx)
Confira tudo com: skystation-verificar
TXT
