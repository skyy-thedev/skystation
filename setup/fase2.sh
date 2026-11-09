#!/bin/bash
# SkyStation: Fase 2
# Login automático no tty1 + cage abrindo o app em tela cheia.
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase2.sh
set -euo pipefail

USER_NAME="sky"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
HOME_DIR="/home/$USER_NAME"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"; exit 1
fi
id "$USER_NAME" >/dev/null 2>&1 || { echo "Usuário $USER_NAME não existe."; exit 1; }

echo "==> [1/5] Instalando pacotes: cage (compositor), pygame (app de teste), fontes, mesa"
pacman -S --needed --noconfirm cage python-pygame ttf-dejavu mesa

echo "==> [2/5] Copiando o console para /opt/skystation"
install -d /opt/skystation
cp -r "$SRC/console/." /opt/skystation/
# Arquivos vindos do Windows podem chegar com fim de linha CRLF; normaliza.
find /opt/skystation -type f \( -name '*.sh' -o -name '*.py' \) -exec sed -i 's/\r$//' {} +
# A pasta compartilhada do VirtualBox entrega arquivos como 770 (só root/vboxsf leem).
# Ao copiar, essas permissões vêm junto: força leitura para todos e execução no script.
chown -R root:root /opt/skystation
chmod -R u=rwX,go=rX /opt/skystation
chmod 755 /opt/skystation/session.sh

echo "==> [3/5] Login automático do $USER_NAME no tty1"
install -Dm644 "$SRC/system/autologin.conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf
sed -i 's/\r$//' /etc/systemd/system/getty@tty1.service.d/autologin.conf

echo "==> [4/5] Abrindo o console no login (~/.bash_profile)"
PROFILE="$HOME_DIR/.bash_profile"
touch "$PROFILE"
if ! grep -q ">>> SKYSTATION >>>" "$PROFILE"; then
    sed 's/\r$//' "$SRC/system/bash_profile.sh" >> "$PROFILE"
fi
chown "$USER_NAME:$USER_NAME" "$PROFILE"

echo "==> [5/5] Permissões de vídeo e controles"
usermod -aG video,input "$USER_NAME"
systemctl daemon-reload

echo ""
echo "Fase 2 instalada. Reinicie com:  sudo reboot"
echo "Saída de emergência: Ctrl Direito + F2 abre outro terminal."
