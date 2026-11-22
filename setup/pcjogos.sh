#!/bin/bash
# SkyStation 13.27: jogos de PC que já estão instalados no Windows (Steam e Epic), jogados daqui.
# Instalado como /usr/local/bin/skystation-pcjogos (root). Roda ao ligar (depois do skystation-skyroms-hd) e
# quando a Steam/Heroic é instalada pela SkyStore.
#
#   skystation-pcjogos            procura as bibliotecas e monta em /mnt/pc
#   skystation-pcjogos parar      desmonta tudo
#   skystation-pcjogos status     mostra o /run/skystation/pcjogos.json
#
# Por que montar de novo: o HD do Windows entra no SkyStation SEM permissão de executar (noexec, sky-security
# 13.2: nada baixado no SKYROMS roda sozinho). Jogo de PC precisa executar, então só a pasta de cada biblioteca
# (…\steamapps e …\Epic Games) ganha um segundo ponto de montagem com exec em /mnt/pc. O resto do HD continua
# sem execução.
#
# O Proton (Steam) guarda um "Windows de mentira" por jogo em steamapps/compatdata. No NTFS isso quebra
# (nomes e permissões do Linux), então compatdata e shadercache ficam no pendrive do sistema
# (~sky/.local/share/skystation/pc/) e entram por cima da pasta do HD só enquanto o SkyStation está ligado.
# No Windows, a Steam nem percebe.
set -uo pipefail

USER_NAME="sky"
BASE="/run/skystation/discos"
ALVO="/mnt/pc"
SAIDA="/run/skystation/pcjogos.json"
CASA="$(getent passwd "$USER_NAME" | cut -d: -f6)"; CASA="${CASA:-/home/$USER_NAME}"
LOCAL="$CASA/.local/share/skystation/pc"

[ "${1:-}" = "status" ] && { cat "$SAIDA" 2>/dev/null || echo '{}'; exit 0; }
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }
install -d -m 755 /run/skystation "$BASE"
log() { echo "pcjogos: $*"; }

parar() {
    # de dentro para fora: primeiro compatdata/shadercache, depois as bibliotecas
    findmnt -rno TARGET | grep "^$ALVO/" | sort -r | while read -r m; do umount "$m" 2>/dev/null || umount -l "$m"; done
    for m in "$BASE"/pc-*; do
        [ -d "$m" ] || continue
        mountpoint -q "$m" && umount "$m" 2>/dev/null
        rmdir "$m" 2>/dev/null
    done
    rm -f "$SAIDA"
}
if [ "${1:-}" = "parar" ]; then parar; log "desmontado"; exit 0; fi
parar

UID_SKY="$(id -u "$USER_NAME" 2>/dev/null || echo 1000)"
GID_SKY="$(id -g "$USER_NAME" 2>/dev/null || echo 1000)"
RAIZ="$(findmnt -rno SOURCE / | sed 's/\[.*//')"
DISCO_SIS="$(lsblk -rnpo PKNAME "$RAIZ" 2>/dev/null | head -1)"
[ -n "$DISCO_SIS" ] || DISCO_SIS="$RAIZ"

# O Windows hibernado (Inicialização rápida) não deixa gravar em nenhum NTFS: monta só leitura.
hibernado() {
    local d mp hib
    while read -r d fs _; do
        [ "$fs" = "ntfs" ] || continue
        mp="$(findmnt -rno TARGET -S "$d" | head -1)"
        [ -n "$mp" ] || continue
        hib="$(find "$mp" -maxdepth 1 -iname hiberfil.sys -print -quit 2>/dev/null)"
        if [ -n "$hib" ] && [ "$(head -c 4 "$hib" 2>/dev/null | tr 'A-Z' 'a-z')" = "hibr" ]; then return 0; fi
    done < <(lsblk -rnpo NAME,FSTYPE)
    return 1
}

# Cada partição NTFS do PC (fora o pendrive do sistema) fica montada em algum lugar: reaproveita a do
# skyroms-hd (/run/skystation/discos/<dev>) ou monta uma nova em /run/skystation/discos/pc-<dev>.
declare -A PONTO MODO
while read -r dev fs tipo; do
    [ "$fs" = "ntfs" ] || continue
    [ "$dev" = "$RAIZ" ] && continue
    [ "$(lsblk -rnpo PKNAME "$dev" 2>/dev/null | head -1)" = "$DISCO_SIS" ] && continue
    mp="$(findmnt -rno TARGET -S "$dev" | grep "^$BASE/" | head -1)"
    if [ -z "$mp" ]; then
        mp="$BASE/pc-$(basename "$dev")"
        install -d "$mp"
        ids="uid=$UID_SKY,gid=$GID_SKY,umask=022"
        mount -t ntfs3 -o "rw,noexec,nosuid,nodev,noatime,$ids,windows_names" "$dev" "$mp" 2>/dev/null \
            || mount -t ntfs3 -o "ro,noexec,nosuid,nodev,noatime,$ids" "$dev" "$mp" 2>/dev/null \
            || { rmdir "$mp"; continue; }
    fi
    PONTO[$dev]="$mp"
    MODO[$dev]="$(findmnt -rno OPTIONS -T "$mp" | tr ',' '\n' | grep -qx ro && echo ro || echo rw)"
done < <(lsblk -rnpo NAME,FSTYPE,TYPE)
if hibernado; then
    log "Windows hibernado: as bibliotecas ficam só leitura (no Windows: powercfg /h off)"
fi

install -d -m 755 "$ALVO"
install -d -o "$USER_NAME" -g "$USER_NAME" "$LOCAL"
steam_json=""; epic_json=""; n=0; e=0

json_esc() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

for dev in "${!PONTO[@]}"; do
    mp="${PONTO[$dev]}"; modo="${MODO[$dev]}"
    letra="$(blkid -s LABEL -o value "$dev" 2>/dev/null)"; letra="${letra:-$(basename "$dev")}"
    # Steam: pastas "steamapps" com appmanifest (D:\SteamLibrary, D:\Program Files (x86)\Steam, D:\Games\Steam…)
    while IFS= read -r -d '' sa; do
        ls "$sa"/appmanifest_*.acf >/dev/null 2>&1 || continue
        n=$((n + 1)); lib="$ALVO/steam$n"; raiz="${sa%/*}"
        install -d "$lib"
        mount --bind "$raiz" "$lib" && mount -o "remount,bind,$modo,exec,nosuid,nodev" "$lib" || { rmdir "$lib"; continue; }
        # compatdata e shadercache no pendrive (ext4), por cima das pastas do HD
        for sub in compatdata shadercache; do
            install -d -o "$USER_NAME" -g "$USER_NAME" "$LOCAL/steam$n-$sub"
            [ -d "$lib/steamapps/$sub" ] || mkdir -p "$lib/steamapps/$sub" 2>/dev/null
            [ -d "$lib/steamapps/$sub" ] && mount --bind "$LOCAL/steam$n-$sub" "$lib/steamapps/$sub"
        done
        origem="${raiz#"$mp"/}"
        steam_json+="${steam_json:+,}{\"ponto\":$(json_esc "$lib"),\"origem\":$(json_esc "$letra/$origem"),\"modo\":\"$modo\"}"
        log "Steam: $letra/$origem → $lib ($modo)"
    done < <(find "$mp" -mindepth 1 -maxdepth 4 -type d -iname steamapps -not -path '*/$RECYCLE.BIN/*' -print0 2>/dev/null)

    # Epic: cada jogo tem a pasta .egstore; a pasta "mãe" (ex.: D:\Program Files\Epic Games) ganha exec
    declare -A MAES=()
    while IFS= read -r -d '' eg; do
        jogo="${eg%/*}"; mae="${jogo%/*}"
        [ -n "${MAES[$mae]:-}" ] || { e=$((e + 1)); MAES[$mae]="$ALVO/epic$e"
            install -d "${MAES[$mae]}"
            mount --bind "$mae" "${MAES[$mae]}" && mount -o "remount,bind,$modo,exec,nosuid,nodev" "${MAES[$mae]}" \
                || { rmdir "${MAES[$mae]}"; MAES[$mae]="-"; }; }
        [ "${MAES[$mae]}" = "-" ] && continue
        app="$(python3 -c 'import json,glob,sys
for f in glob.glob(sys.argv[1] + "/*.mancpn"):
    try:
        d = json.load(open(f)); print(d.get("AppName", "")); break
    except Exception: pass' "$eg")"
        [ -n "$app" ] || continue
        epic_json+="${epic_json:+,}{\"appName\":$(json_esc "$app"),\"titulo\":$(json_esc "${jogo##*/}"),\"ponto\":$(json_esc "${MAES[$mae]}/${jogo##*/}"),\"modo\":\"$modo\"}"
        log "Epic: ${jogo##*/} ($app) → ${MAES[$mae]}"
    done < <(find "$mp" -mindepth 2 -maxdepth 5 -type d -name .egstore -not -path '*/$RECYCLE.BIN/*' -print0 2>/dev/null)
    unset MAES
done

printf '{"t":%s,"steam":[%s],"epic":[%s],"hibernado":%s}\n' "$(date +%s)" "$steam_json" "$epic_json" \
    "$(hibernado && echo true || echo false)" >"$SAIDA.tmp" && chmod 644 "$SAIDA.tmp" && mv -f "$SAIDA.tmp" "$SAIDA"
log "$n biblioteca(s) da Steam, $e pasta(s) da Epic"
# avisa o console (o sky-pc monta os jogos no menu quando roda como o usuário)
touch /run/skystation/pcjogos.mudou 2>/dev/null
exit 0
