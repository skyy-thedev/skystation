#!/bin/bash
# SkyStation: Fase 5
#   A. Menu Home por cima do jogo (pausa + Voltar ao jogo / Fechar jogo)
#   B. Boot silencioso: logo do SkyStation do GRUB ao launcher, sem texto de terminal
#   C. Configurações no launcher: Wi-Fi, Bluetooth, Som e Sistema
# Pré-requisito: Fase 4 instalada.
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase5.sh
set -euo pipefail

USER_NAME="sky"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
UHOME="/home/$USER_NAME"
step() { echo; echo "==> $*"; }

[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
[ -f /opt/skystation/bin/sky-run ] || { echo "Instale a Fase 4 antes (setup/fase4.sh)."; exit 1; }

step "[1/6] Pacotes: Plymouth (tela de boot) e BlueZ (Bluetooth)"
pacman -S --needed --noconfirm plymouth bluez bluez-utils python-pygame
systemctl enable bluetooth.service

step "[2/6] Tema de boot do SkyStation"
install -d /usr/share/plymouth/themes/skystation
install -m 644 "$SRC"/system/plymouth/skystation/* /usr/share/plymouth/themes/skystation/
plymouth-set-default-theme skystation

step "[3/6] Plymouth dentro da imagem de inicialização"
CONF=/etc/mkinitcpio.conf
if ! grep -qE '^HOOKS=.*\bplymouth\b' "$CONF"; then
    cp "$CONF" "$CONF.antes-fase5"
    if grep -qE '^HOOKS=.*\bsystemd\b' "$CONF"; then
        sed -i -E '/^HOOKS=/ s/\bsystemd\b/systemd plymouth/' "$CONF"
    else
        sed -i -E '/^HOOKS=/ s/\budev\b/udev plymouth/' "$CONF"
    fi
fi
grep '^HOOKS=' "$CONF" || true
mkinitcpio -P

step "[4/6] GRUB invisível e kernel silencioso"
G=/etc/default/grub
if [ -f "$G" ]; then
    cp "$G" "$G.antes-fase5"
    setkey() {  # setkey CHAVE VALOR  (cria ou substitui)
        if grep -qE "^#?$1=" "$G"; then sed -i -E "s|^#?$1=.*|$1=$2|" "$G"; else echo "$1=$2" >>"$G"; fi
    }
    setkey GRUB_TIMEOUT 0
    setkey GRUB_TIMEOUT_STYLE hidden
    setkey GRUB_CMDLINE_LINUX_DEFAULT '"quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false"'
    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "   AVISO: /etc/default/grub não encontrado; boot silencioso parcial."
fi

step "[5/6] Login automático sem nenhum texto"
install -Dm644 "$SRC/system/autologin.conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf
sed -i 's/\r$//' /etc/systemd/system/getty@tty1.service.d/autologin.conf
touch "$UHOME/.hushlogin" && chown "$USER_NAME:$USER_NAME" "$UHOME/.hushlogin"
# troca o bloco do SkyStation no ~/.bash_profile pela versão nova (cursor escondido, tela limpa)
PROFILE="$UHOME/.bash_profile"
if [ -f "$PROFILE" ]; then
    sed -i '/# >>> SKYSTATION >>>/,/# <<< SKYSTATION <<</d' "$PROFILE"
fi
sed 's/\r$//' "$SRC/system/bash_profile.sh" >>"$PROFILE"
chown "$USER_NAME:$USER_NAME" "$PROFILE"
systemctl daemon-reload

step "[6/6] Console: menu Home, Configurações e launcher"
bash "$SRC/setup/atualizar.sh"

echo
echo "Fase 5 instalada. Reinicie para ver o boot novo:  sudo reboot"
echo "Precisa ver o boot com texto (diagnóstico)? No GRUB, segure Shift ou Esc ao ligar."
