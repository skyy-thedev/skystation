#!/bin/bash
# SkyStation: Fase 5.5 — visual novo, Bluetooth sem atraso e espaço sob controle.
#   - interface em "barra cruzada" (categorias na horizontal, itens na vertical) com fundo de
#     ondas animado, sons próprios e temas de cor  (vem com o skystation-atualizar)
#   - boot animado: ondas em movimento, brilho e partículas (Plymouth) — requer refazer o UKI
#   - Bluetooth: sem economia de energia no rádio e com convivência Wi-Fi/Bluetooth (Atheros)
#   - espaço: cache do pacman limpo após cada instalação; pendrive de jogos "SKYROMS" automático
#   - "Atualizar o SkyStation" direto pelo menu (sem senha, só para esse comando)
# Uso:  sudo bash /opt/skystation-src/setup/fase5-5.sh      (na VM: /mnt/skystation/setup/fase5-5.sh)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"
UID_SKY="$(id -u "$USER_NAME")"
GID_SKY="$(id -g "$USER_NAME")"

echo "==> [1/6] Console (launcher novo)"
bash "$SRC/setup/atualizar.sh"

echo "==> [2/6] Boot animado (Plymouth)"
THEME=/usr/share/plymouth/themes/skystation
install -d "$THEME"
before="$(cat "$THEME"/* 2>/dev/null | md5sum)"
install -m 644 "$SRC"/system/plymouth/skystation/* "$THEME"/
sed -i 's/\r$//' "$THEME"/*.plymouth "$THEME"/*.script
after="$(cat "$THEME"/* | md5sum)"
if [ "$before" != "$after" ]; then
    free_mb="$(df -m --output=avail /boot | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -lt 120 ]; then
        echo "    /boot com pouco espaço (${free_mb} MB): pulei o mkinitcpio. A animação nova entra depois."
    else
        echo "    Refazendo a imagem de boot (pode levar alguns minutos no pendrive)…"
        mkinitcpio -P >/tmp/skystation-mkinitcpio.log 2>&1 || { echo "    mkinitcpio falhou: veja /tmp/skystation-mkinitcpio.log"; exit 1; }
    fi
else
    echo "    Tema de boot já estava atualizado."
fi

echo "==> [3/6] Bluetooth com menos atraso"
cat >/etc/modprobe.d/skystation-bt.conf <<'CONF'
# SkyStation: o adaptador Bluetooth não "cochila" entre um pacote e outro (causa atraso no controle)
options btusb enable_autosuspend=n
# Placas Atheros com Wi-Fi + Bluetooth no mesmo chip: os dois rádios combinam quem fala quando
options ath9k btcoex_enable=1
CONF
install -d /etc/NetworkManager/conf.d
cat >/etc/NetworkManager/conf.d/skystation-wifi.conf <<'CONF'
# SkyStation: Wi-Fi sem economia de energia (menos disputa com o Bluetooth, menos latência)
[connection]
wifi.powersave = 2
CONF

echo "==> [4/6] Espaço: cache do pacman some depois de cada instalação"
install -d /etc/pacman.d/hooks
cat >/etc/pacman.d/hooks/skystation-cache.hook <<'CONF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = SkyStation: limpando o cache de pacotes (mídia pequena)
When = PostTransaction
Exec = /usr/bin/find /var/cache/pacman/pkg -maxdepth 1 -type f -name *.pkg.tar* -delete
CONF
find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true

echo "==> [5/6] Pendrive de jogos SKYROMS (monta sozinho em /mnt/skyroms)"
cat >/etc/udev/rules.d/90-skystation-roms.rules <<RULES
# SkyStation: pendrive com o rótulo SKYROMS vira a pasta /mnt/skyroms (ps1/, ps2/ dentro dele).
# exFAT/FAT32 (formatado no Windows): arquivos do usuário sky. Ao tirar o pendrive, desmonta sozinho.
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="SKYROMS", ENV{ID_FS_TYPE}=="exfat|vfat", RUN{program}+="/usr/bin/systemd-mount --no-block --collect --options=uid=$UID_SKY,gid=$GID_SKY,umask=022,noatime \$devnode /mnt/skyroms"
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="SKYROMS", ENV{ID_FS_TYPE}=="ext4", RUN{program}+="/usr/bin/systemd-mount --no-block --collect --options=noatime \$devnode /mnt/skyroms"
RULES
udevadm control --reload-rules || true
udevadm trigger --subsystem-match=block --action=add || true

echo "==> [6/6] Atualizar pelo menu do console (só este comando, sem senha)"
cat >/etc/sudoers.d/skystation <<CONF
# SkyStation: o menu "Atualizar o SkyStation" roda isto sem pedir senha (e só isto).
$USER_NAME ALL=(root) NOPASSWD: /usr/local/bin/skystation-atualizar, /usr/local/bin/skystation-atualizar --github
CONF
chmod 440 /etc/sudoers.d/skystation
visudo -cf /etc/sudoers.d/skystation >/dev/null || { rm -f /etc/sudoers.d/skystation; echo "    sudoers inválido: removido"; }

echo
df -h / | tail -1 | awk '{print "Espaço livre no sistema: " $4 " de " $2}'
echo "Fase 5.5 instalada. Reinicie para ver o boot novo e aplicar o Bluetooth:  sudo reboot"
