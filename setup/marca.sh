#!/bin/bash
# SkyStation: identidade do sistema. Instalado como /usr/local/bin/skystation-marca.
# Roda na Fase 5.1 e sempre que o pacman atualizar "filesystem" ou "grub" (hook).
set -u
SRC_OS="/usr/local/share/skystation/os-release"

# 1) Nome do sistema: o Plymouth (modo texto), o GRUB e várias ferramentas leem daqui.
if [ -f "$SRC_OS" ]; then
    rm -f /etc/os-release
    install -m 644 "$SRC_OS" /etc/os-release
fi

# 2) GRUB: nome "SkyStation" e sem as mensagens "Loading Linux..." / "Loading initial ramdisk..."
G=/etc/default/grub
if [ -f "$G" ] && [ -d /boot/grub ]; then
    setkey() { if grep -qE "^#?$1=" "$G"; then sed -i -E "s|^#?$1=.*|$1=$2|" "$G"; else echo "$1=$2" >>"$G"; fi; }
    setkey GRUB_DISTRIBUTOR '"SkyStation"'
    setkey GRUB_GFXPAYLOAD_LINUX keep
    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    sed -i -E '/^\s*echo\s/d' /boot/grub/grub.cfg
fi
# 3) systemd-boot (o archinstall pode ter escolhido ele em vez do GRUB):
#    menu escondido, entradas com o nome SkyStation e kernel em modo silencioso com splash.
ESP="$(bootctl --print-esp-path 2>/dev/null || findmnt -n -o TARGET -t vfat | head -1)"
if [ -n "$ESP" ] && [ -d "$ESP/loader/entries" ]; then
    LC="$ESP/loader/loader.conf"
    touch "$LC"
    lkey() { if grep -qE "^#?\s*$1\b" "$LC"; then sed -i -E "s|^#?\s*$1\b.*|$1 $2|" "$LC"; else echo "$1 $2" >>"$LC"; fi; }
    lkey timeout 0          # menu invisível (segure Espaço ao ligar para ver)
    lkey editor no
    for e in "$ESP"/loader/entries/*.conf; do
        [ -f "$e" ] || continue
        if grep -qi fallback "$e"; then
            sed -i -E 's|^title\s.*|title   SkyStation (modo de recuperação)|' "$e"
        else
            sed -i -E 's|^title\s.*|title   SkyStation|' "$e"
            grep -qE '^options.*\bsplash\b' "$e" || \
                sed -i -E '/^options/ s|$| quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false|' "$e"
        fi
    done
fi
# 4) UKI (Unified Kernel Image): kernel + initramfs + linha de comando num único .efi.
#    Nesse modo a linha de comando vem de /etc/kernel/cmdline e o logo do começo do boot
#    (o do Arch) vem da opção --splash do preset do mkinitcpio. Troca pelo logo do SkyStation.
PRESET=/etc/mkinitcpio.d/linux.preset
SPLASH=/usr/local/share/skystation/splash.bmp
if [ -f "$PRESET" ] && grep -qE '^[^#]*_uki=' "$PRESET"; then
    before="$(cat /etc/kernel/cmdline "$PRESET" 2>/dev/null | md5sum)"
    CMD=/etc/kernel/cmdline
    if [ ! -f "$CMD" ]; then
        sed -E 's/(^| )(BOOT_IMAGE|initrd)=[^ ]*//g' /proc/cmdline >"$CMD"
    fi
    for p in quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false; do
        grep -qE "(^| )$p( |$)" "$CMD" || sed -i -E "1 s|[[:space:]]*$| $p|" "$CMD"
    done
    if [ -f "$SPLASH" ]; then
        if grep -q -- '--splash' "$PRESET"; then
            sed -i -E "s|--splash[= ][^ \"']*|--splash $SPLASH|g" "$PRESET"
        elif grep -q '^default_options=' "$PRESET"; then
            sed -i -E "s|^default_options=\"|default_options=\"--splash $SPLASH |" "$PRESET"
        else
            echo "default_options=\"--splash $SPLASH\"" >>"$PRESET"
        fi
    fi
    after="$(cat /etc/kernel/cmdline "$PRESET" 2>/dev/null | md5sum)"
    if [ "$before" != "$after" ]; then
        echo "SkyStation: recriando a imagem de boot (UKI)..."
        mkinitcpio -P >/dev/null
    fi
fi
echo "SkyStation: identidade aplicada."
