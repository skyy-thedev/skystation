#!/bin/bash
# SkyStation: Fase 5.4. Vídeo mais robusto e "modo turbo" da VM.
#   - se a GPU falhar de qualquer jeito, o console cai para o modo CPU sozinho (antes: erro 134)
#   - comando skystation-vm: resolução do console e modo de vídeo (auto / hibrido / software)
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase5-4.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }
pacman -S --needed --noconfirm wlr-randr
bash "$SRC/setup/atualizar.sh"
ln -sf /opt/skystation/bin/skystation-vm /usr/local/bin/skystation-vm
echo
echo "Fase 5.4 instalada. Exemplo (como usuário sky, sem sudo):"
echo "  skystation-vm resolucao 960x540"
echo "  logout"
