#!/bin/bash
# SkyStation: ajuda para instalar programas que vêm em AppImage (RPCS3, Xenia…). Usado com "source".
#
# instalar_appimage <arquivo.AppImage> <pasta de destino>
#   Extrai o AppImage (o console não usa FUSE) e coloca o conteúdo em <destino>, com <destino>/AppRun.
#   Aceita os dois tipos de AppImage: o antigo (extrai em squashfs-root/) e o novo "uruntime"
#   (extrai em AppDir/). Se não der para extrair, guarda o próprio AppImage e cria um AppRun que o
#   abre no modo "extrair e rodar". Devolve 0 só se <destino>/AppRun existir e for executável.
# Tudo é anotado em /var/log/skystation-instalar.log (e copiado para SKYROMS/diag-instalar.txt).

LOG_INST="/var/log/skystation-instalar.log"

anota() { echo "[$(date '+%F %T')] $*" >>"$LOG_INST"; }

copia_log() {   # deixa o log no HD/pendrive SKYROMS para ser lido no Windows
    [ -w /mnt/skyroms ] && cp -f "$LOG_INST" /mnt/skyroms/diag-instalar.txt 2>/dev/null
    return 0
}

instalar_appimage() {
    local img="$1" dest="$2" tmp dir
    tmp="$(mktemp -d /var/tmp/skystation-appimage.XXXXXX)"   # /var/tmp: no disco, não na RAM
    anota "instalar_appimage $img -> $dest ($(stat -c %s "$img" 2>/dev/null) bytes)"
    chmod +x "$img"
    if (cd "$tmp" && "$img" --appimage-extract >>"$LOG_INST" 2>&1 </dev/null) ; then
        anota "extração terminou"
    else
        anota "extração falhou (código $?)"
    fi
    dir=""
    # O runtime novo extrai em AppDir/ e cria "squashfs-root" como ATALHO para ela. Mover o atalho e
    # apagar a pasta temporária deixava /opt/rpcs3 apontando para o nada (era o bug da Fase 7.0).
    for d in AppDir squashfs-root; do [ -d "$tmp/$d" ] && { dir="$(readlink -f "$tmp/$d")"; break; }; done
    [ -z "$dir" ] && dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d ! -type l | head -1)"
    anota "pasta extraída: ${dir:-nenhuma}; conteúdo: $(ls "$dir" 2>/dev/null | head -20 | tr '\n' ' ')"
    rm -rf "$dest"
    if [ -n "$dir" ] && [ -e "$dir/AppRun" ]; then
        mv "$dir" "$dest"
        chmod -R a+rX "$dest"; chmod a+x "$dest/AppRun" 2>/dev/null
    else
        anota "sem AppRun extraído: usando o AppImage direto (modo extrair-e-rodar)"
        install -d "$dest"
        mv "$img" "$dest/programa.AppImage"; chmod 755 "$dest/programa.AppImage"
        cat >"$dest/AppRun" <<'RUN'
#!/bin/sh
# SkyStation: o AppImage não pôde ser extraído na instalação; roda sem FUSE, extraindo a cada abertura.
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$(dirname "$(readlink -f "$0")")/programa.AppImage" "$@"
RUN
        chmod 755 "$dest/AppRun"
    fi
    rm -rf "$tmp"
    if [ -x "$dest/AppRun" ]; then anota "ok: $dest/AppRun"; copia_log; return 0; fi
    anota "ERRO: $dest/AppRun não ficou executável"; copia_log; return 1
}
