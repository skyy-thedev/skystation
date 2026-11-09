#!/bin/bash
# SkyStation: Fase 5.6 — portátil, avisos e mais recursos.
#   - bateria do console e dos controles na tela, perfil econômico na bateria, aviso em 15% e 5%,
#     desligamento seguro em 3% (o jogo é fechado do jeito certo antes)
#   - sons de aviso: controle, USB, pendrive de jogos, jogo novo, carregador, bateria, temperatura
#   - brilho e volume pelo menu, saída de som (alto-falantes / TV), descanso de tela
#   - menu Home: salvar/carregar estado (PS1), captura de tela, volume, bateria e temperatura
#   - capas automáticas, tempo de jogo + Recentes, Capturas, aviso de nova versão, música ambiente
# Uso:  sudo bash /opt/skystation-src/setup/fase5-6.sh      (na VM: /mnt/skystation/setup/fase5-6.sh)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
USER_NAME="sky"

echo "==> [1/5] Pacotes: grim (captura de tela) e brightnessctl (brilho)"
PKGS="grim brightnessctl"
if ! pacman -S --needed --noconfirm $PKGS; then
    # banco de pacotes antigo (imagem gravada há dias): atualiza tudo junto, se houver espaço
    free_mb="$(df -m --output=avail / | tail -1 | tr -d ' ')"
    if [ "${free_mb:-0}" -lt 1500 ]; then
        echo "    Pouco espaço (${free_mb} MB) para atualizar o sistema. Captura e brilho ficam para depois."
    else
        echo "    Atualizando o sistema para instalar os pacotes (o cache é apagado no final)…"
        pacman -Syu --needed --noconfirm $PKGS || echo "    Não consegui instalar $PKGS agora."
    fi
fi
usermod -aG video "$USER_NAME" || true   # brilho da tela sem senha

echo "==> [2/5] Console (launcher, menu Home, avisos, sons, música)"
bash "$SRC/setup/atualizar.sh"

echo "==> [3/5] Energia: CPU econômica na bateria"
sed 's/\r$//' "$SRC/setup/energia.sh" >/usr/local/bin/skystation-energia
chmod 755 /usr/local/bin/skystation-energia
cat >/etc/udev/rules.d/91-skystation-energia.rules <<'RULES'
# SkyStation: carregador entrou/saiu -> ajusta o perfil de energia da CPU
SUBSYSTEM=="power_supply", ACTION=="change", RUN+="/usr/local/bin/skystation-energia"
RULES
cat >/etc/systemd/system/skystation-energia.service <<'UNIT'
[Unit]
Description=SkyStation: perfil de energia da CPU (tomada/bateria)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/skystation-energia
UNIT
cat >/etc/systemd/system/skystation-energia.timer <<'UNIT'
[Unit]
Description=SkyStation: reaplica o perfil de energia a cada minuto

[Timer]
OnBootSec=20
OnUnitActiveSec=60

[Install]
WantedBy=timers.target
UNIT
udevadm control --reload-rules || true
systemctl daemon-reload
systemctl enable --now skystation-energia.timer >/dev/null 2>&1 || true
/usr/local/bin/skystation-energia

echo "==> [4/5] Pastas do usuário"
install -d -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/skystation/capturas" "/home/$USER_NAME/skystation/saves"

echo "==> [5/5] Limpeza"
find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
df -h / | tail -1 | awk '{print "Espaço livre no sistema: " $4 " de " $2}'
echo
echo "Fase 5.6 instalada. Reinicie para valer tudo (grupo de vídeo, energia):  sudo reboot"
