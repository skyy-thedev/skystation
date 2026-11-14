#!/bin/bash
# SkyStation: Fase 7.6 — jogos direto do HD/SSD do PC (comando skystation-skyroms-hd, roda como root).
#
# Procura, nos discos do PC (fora o pendrive do sistema), uma pasta chamada SKYROMS na raiz de
# alguma partição (ou um nível abaixo, ex.: D:\Jogos\SKYROMS). Achou: monta a partição e "espelha"
# a pasta em /mnt/skyroms — o mesmo lugar do pendrive SKYROMS, então PS1, PS2, PS3, PSP, Nintendo,
# Xbox 360, capas, mover jogos e Central web funcionam sem mudar nada.
#
# Windows (NTFS) só é montado com escrita quando é seguro. Se o Windows estiver hibernado
# (Inicialização rápida ligada) ou o disco não foi desligado direito, monta só leitura: os jogos
# rodam, mas nada é gravado no HD (gravar ali faria o Windows perder dados ao voltar).
#
# Uso:  sudo skystation-skyroms-hd          procurar e montar (o boot já faz isso sozinho)
#       sudo skystation-skyroms-hd parar    desmontar com segurança
#       skystation-skyroms-hd status        mostra o que foi encontrado
# Resultado para o console: /run/skystation/skyroms-hd (chave=valor).
set -uo pipefail

USER_NAME="sky"
ALVO="/mnt/skyroms"
BASE="/run/skystation/discos"
STATUS="/run/skystation/skyroms-hd"
TIPOS=" ntfs exfat vfat ext4 btrfs xfs "

[ "${1:-}" = "status" ] && { cat "$STATUS" 2>/dev/null || echo "estado=nao-procurado"; exit 0; }
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }
install -d -m 755 /run/skystation "$BASE"

log() { echo "skyroms-hd: $*"; }
grava() { printf '%s\n' "$@" >"$STATUS.tmp" && chmod 644 "$STATUS.tmp" && mv -f "$STATUS.tmp" "$STATUS"; }
nosso() { [ -f "$STATUS" ] && grep -q '^estado=ok' "$STATUS"; }

parar() {
    if nosso; then
        local dev; dev="$(sed -n 's/^dev=//p' "$STATUS")"
        while findmnt -rno SOURCE "$ALVO" 2>/dev/null | sed 's/\[.*//' | grep -qxF "$dev"; do umount "$ALVO" 2>/dev/null || break; done
    fi
    for mp in "$BASE"/*; do
        [ -d "$mp" ] || continue
        mountpoint -q "$mp" && umount "$mp" 2>/dev/null
        rmdir "$mp" 2>/dev/null
    done
    rm -f "$STATUS"
}
if [ "${1:-}" = "parar" ]; then parar; log "desmontado"; exit 0; fi

parar   # recomeça do zero (ex.: rodado de novo depois de criar a pasta)

UID_SKY="$(id -u "$USER_NAME" 2>/dev/null || echo 1000)"
GID_SKY="$(id -g "$USER_NAME" 2>/dev/null || echo 1000)"

# Disco do sistema (o pendrive do SkyStation): nunca mexe nele.
RAIZ="$(findmnt -rno SOURCE / | sed 's/\[.*//')"
DISCO_SIS="$(lsblk -rnpo PKNAME "$RAIZ" 2>/dev/null | head -1)"
[ -n "$DISCO_SIS" ] || DISCO_SIS="$RAIZ"

# monta_disco <dev> <tipo> <ponto> <ro|rw>
monta_disco() {
    local dev="$1" fs="$2" mp="$3" modo="$4" ids="uid=$UID_SKY,gid=$GID_SKY,umask=022"
    case "$fs" in
        ntfs)
            # ntfs3 = driver do próprio kernel (rápido). ntfs-3g (FUSE) só se o ntfs3 falhar.
            mount -t ntfs3 -o "$modo,noatime,$ids,windows_names" "$dev" "$mp" 2>/dev/null \
                || mount -t ntfs3 -o "$modo,noatime,$ids" "$dev" "$mp" 2>/dev/null \
                || { command -v ntfs-3g >/dev/null && mount -t ntfs-3g -o "$modo,noatime,$ids" "$dev" "$mp" 2>/dev/null; } ;;
        exfat|vfat) mount -t "$fs" -o "$modo,noatime,$ids" "$dev" "$mp" 2>/dev/null ;;
        *)          mount -t "$fs" -o "$modo,noatime" "$dev" "$mp" 2>/dev/null ;;
    esac
}

# Pendrive SKYROMS já conectado: ele tem prioridade. (Se for conectado depois, ele cobre o HD e,
# ao ser tirado, os jogos do HD voltam sozinhos.)
if mountpoint -q "$ALVO"; then
    grava "estado=pendrive"; log "pendrive SKYROMS conectado: ele tem prioridade"; exit 0
fi

achou_bitlocker=""
while read -r dev fs tipo label; do
    [ "$tipo" = "part" ] || [ "$tipo" = "disk" ] || continue
    case "$fs" in BitLocker) achou_bitlocker="$dev"; continue ;; esac
    case "$TIPOS" in *" $fs "*) ;; *) continue ;; esac
    [ "$dev" = "$RAIZ" ] && continue
    [ "$(lsblk -rnpo PKNAME "$dev" 2>/dev/null | head -1)" = "$DISCO_SIS" ] && continue
    [ "$label" = "SKYROMS" ] && continue                  # pendrive SKYROMS: a regra do udev cuida
    findmnt -rn -S "$dev" >/dev/null 2>&1 && continue     # já montado em outro lugar

    mp="$BASE/$(basename "$dev")"
    install -d "$mp"
    monta_disco "$dev" "$fs" "$mp" ro || { rmdir "$mp"; continue; }

    pasta="$(find "$mp" -mindepth 1 -maxdepth 2 -type d -iname skyroms -printf '%d %P\n' 2>/dev/null \
             | sort -n | head -1 | cut -d' ' -f2-)"
    if [ -z "$pasta" ]; then umount "$mp"; rmdir "$mp"; continue; fi

    # Pode gravar? No NTFS, não se o Windows estiver hibernado ou o disco estiver "sujo".
    modo="rw"; motivo=""
    if [ "$fs" = "ntfs" ]; then
        hib="$(find "$mp" -maxdepth 1 -iname hiberfil.sys -print -quit 2>/dev/null)"
        if [ -n "$hib" ] && [ "$(head -c 4 "$hib" 2>/dev/null | tr 'A-Z' 'a-z')" = "hibr" ]; then
            modo="ro"; motivo="windows-hibernado"
        fi
    fi
    if [ "$modo" = "rw" ]; then
        umount "$mp"
        if ! monta_disco "$dev" "$fs" "$mp" rw; then
            monta_disco "$dev" "$fs" "$mp" ro || { rmdir "$mp"; continue; }
            modo="ro"; motivo="disco-nao-desligado-direito"
        fi
    fi

    install -d "$ALVO"
    if ! mount --bind "$mp/$pasta" "$ALVO"; then umount "$mp"; rmdir "$mp"; continue; fi
    [ "$modo" = "ro" ] && mount -o remount,bind,ro "$ALVO" 2>/dev/null

    nome="${label:-$(lsblk -rnpo SIZE "$dev" | head -1)}"
    grava "estado=ok" "dev=$dev" "fs=$fs" "modo=$modo" "motivo=$motivo" "pasta=$pasta" \
          "disco=$(printf '%b' "$nome")" "ponto=$mp"
    log "jogos em $dev ($fs, $modo${motivo:+, $motivo}) → pasta $pasta"
    exit 0
done < <(lsblk -rnpo NAME,FSTYPE,TYPE,LABEL)

if [ -n "$achou_bitlocker" ]; then
    grava "estado=bitlocker" "dev=$achou_bitlocker"
    log "nenhuma pasta SKYROMS; $achou_bitlocker está criptografado (BitLocker) e não dá para ler"
else
    grava "estado=nao-encontrado"
    log "nenhuma pasta SKYROMS nos discos do PC"
fi
exit 0
