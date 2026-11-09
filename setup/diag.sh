#!/bin/bash
# SkyStation: diagnóstico do boot. Instalado como /usr/local/bin/skystation-diag.
# Grava um relatório na pasta compartilhada (VM) ou em ~/skystation/diag-boot.txt.
OUT=/home/sky/skystation/diag-boot.txt
[ -w /mnt/skystation ] && OUT=/mnt/skystation/diag-boot.txt
{
    echo "=== $(date '+%F %T')"
    echo "--- cmdline";            cat /proc/cmdline
    echo "--- tema padrão";        plymouth-set-default-theme 2>&1
    echo "--- plymouthd.conf";     cat /etc/plymouth/plymouthd.conf 2>&1
    echo "--- plymouthd.defaults"; cat /usr/share/plymouth/plymouthd.defaults 2>&1
    echo "--- arquivos do tema";   ls -la /usr/share/plymouth/themes/skystation 2>&1
    echo "--- HOOKS";              grep '^HOOKS=' /etc/mkinitcpio.conf
    echo "--- /boot";              ls -la /boot
    echo "--- preset mkinitcpio";  grep -v '^\s*$' /etc/mkinitcpio.d/linux.preset 2>&1
    echo "--- /etc/kernel/cmdline"; cat /etc/kernel/cmdline 2>&1
    echo "--- UKIs";               ls -la /boot/EFI/Linux /efi/EFI/Linux 2>/dev/null
    echo "--- bootloader";         bootctl status 2>&1 | grep -E 'Product|Current Entry|Default Entry|ESP:' | head
    ESP="$(bootctl --print-esp-path 2>/dev/null)"
    [ -n "$ESP" ] && { echo "--- loader.conf"; cat "$ESP/loader/loader.conf"; echo "--- entries"; cat "$ESP"/loader/entries/*.conf; }
    echo "--- plymouth dentro do initramfs"
    for img in /boot/initramfs-linux.img "$ESP"/initramfs-linux.img; do
        [ -f "$img" ] && { echo "[$img]"; lsinitcpio -l "$img" 2>&1 | grep -iE 'plymouth' | grep -E 'themes|plymouthd|script' | head -20; break; }
    done
    echo "--- grub (echo / linux)"; grep -nE '^\s*(echo|linux)\s' /boot/grub/grub.cfg 2>&1 | head
    echo "--- os-release";         cat /etc/os-release
    echo "--- journal: plymouth (boot atual)"
    journalctl -b --no-pager 2>/dev/null | grep -iE 'plymouth|splash|theme' | tail -40
} >"$OUT" 2>&1
chmod 644 "$OUT" 2>/dev/null
echo "Diagnóstico salvo em $OUT"
