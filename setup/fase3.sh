#!/bin/bash
# SkyStation: Fase 3
# Launcher em Godot + jogos de exemplo + comando "skystation-atualizar".
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase3.sh
set -euo pipefail

USER_NAME="sky"
SRC="$(cd "$(dirname "$0")/.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"; exit 1
fi

echo "==> [1/4] Instalando Godot e XWayland (plano B de janela)"
pacman -S --needed --noconfirm godot xorg-xwayland python-pygame

echo "==> [2/4] Instalando o comando skystation-atualizar"
cat > /usr/local/bin/skystation-atualizar <<'EOF'
#!/bin/bash
exec bash /mnt/skystation/setup/atualizar.sh "$@"
EOF
chmod 755 /usr/local/bin/skystation-atualizar

echo "==> [3/4] Pasta para jogos do usuário (~/skystation/games)"
install -d -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/skystation" "/home/$USER_NAME/skystation/games"

echo "==> [4/4] Copiando launcher e jogos para /opt/skystation"
bash "$SRC/setup/atualizar.sh"

echo ""
echo "Fase 3 instalada. Para abrir o launcher:  logout"
echo "Daqui para frente, para aplicar mudanças:  sudo skystation-atualizar && logout"
