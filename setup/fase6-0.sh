#!/bin/bash
# SkyStation: Fase 5.9 + 6.0 — desempenho por jogo no PS2, Modo TV, Central web e Copiar disco.
# Uso:  sudo bash /opt/skystation-src/setup/fase6-0.sh      (na VM: /mnt/skystation/setup/fase6-0.sh)
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

instalar() {   # instala o que der; um pacote que falte não derruba o resto
    for p in "$@"; do
        pacman -Q "$p" >/dev/null 2>&1 && continue
        if ! pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then
            free_mb="$(df -m --output=avail / | tail -1 | tr -d ' ')"
            if [ "${free_mb:-0}" -ge 1500 ] && pacman -Syu --needed --noconfirm "$p" >/dev/null 2>&1; then
                echo "    $p instalado (com atualização do sistema: reinicie no fim)"
            else
                echo "    AVISO: não consegui instalar $p agora"
                continue
            fi
        fi
        echo "    $p ok"
    done
}

echo "==> [1/3] Pacotes: cdrdao (copiar CD de PS1 com faixas de áudio), mame-tools (chdman: compactar)"
instalar cdrdao mame-tools libpulse
command -v chdman >/dev/null || echo "    Sem chdman: 'Compactar (CHD)' fica indisponível; copiar disco continua funcionando."

echo "==> [2/3] Console (launcher, Central web, Modo TV, sky-jogos, sky-pcsx2-ini)"
bash "$SRC/setup/atualizar.sh"

echo "==> [3/3] Modo TV"
if cage -h 2>&1 | grep -q -- "-m extend"; then
    echo "    cage com '-m last': ao ligar o HDMI, a imagem vai para a TV sozinha"
else
    echo "    AVISO: este cage não tem a opção -m (atualize o sistema): a imagem não troca sozinha"
fi
ls /sys/class/drm/ 2>/dev/null | grep -E -- "-(HDMI|DP|VGA)-" | sed 's/^/    saída: /' || true

find /var/cache/pacman/pkg -maxdepth 1 -type f -name '*.pkg.tar*' -delete 2>/dev/null || true
echo
echo "Fase 6.0 instalada. Reinicie para o Modo TV valer:  sudo reboot"
