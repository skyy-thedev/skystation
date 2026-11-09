#!/bin/bash
# SkyStation: "deploy" do console.
# Copia a pasta console/ do projeto para /opt/skystation com as permissões certas.
# Uso:  sudo skystation-atualizar   (na VM usa a pasta compartilhada; no notebook baixa do GitHub)
set -euo pipefail

USER_NAME="sky"
SRC="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo."; exit 1
fi

install -d /opt/skystation
cp -r "$SRC/console/." /opt/skystation/

# Arquivos vindos do Windows podem ter fim de linha CRLF; normaliza os de texto.
find /opt/skystation -type f \( -name '*.sh' -o -name '*.py' -o -name '*.gd' \
    -o -name '*.godot' -o -name '*.tscn' -o -name '*.json' \) -exec sed -i 's/\r$//' {} +

# A pasta compartilhada do VirtualBox entrega tudo como 770: força leitura para todos.
chown -R root:root /opt/skystation
chmod -R u=rwX,go=rX /opt/skystation
chmod 755 /opt/skystation/session.sh
[ -d /opt/skystation/bin ] && chmod 755 /opt/skystation/bin/*

# O Godot grava um cache (.godot/) dentro da pasta do projeto: o launcher pertence ao usuário.
if [ -d /opt/skystation/launcher ]; then
    chown -R "$USER_NAME:$USER_NAME" /opt/skystation/launcher
    if command -v godot >/dev/null 2>&1; then
        echo "==> Preparando o cache do launcher (Godot --import)"
        sudo -u "$USER_NAME" godot --headless --path /opt/skystation/launcher --import >/dev/null 2>&1 || true
    fi
fi

# Comandos do sistema (skystation-*) sempre na versão mais nova do projeto.
for pair in skystation-atualizar.sh:skystation-atualizar expandir.sh:skystation-expandir \
            diag.sh:skystation-diag marca.sh:skystation-marca diag-controle.sh:skystation-diag-controle \
            energia.sh:skystation-energia som-ligar.sh:skystation-som-ligar; do
    f="$SRC/setup/${pair%%:*}"; [ -f "$f" ] || continue
    sed 's/\r$//' "$f" > "/usr/local/bin/${pair##*:}.new"
    chmod 755 "/usr/local/bin/${pair##*:}.new"
    mv -f "/usr/local/bin/${pair##*:}.new" "/usr/local/bin/${pair##*:}"
done

# Versão: commit do Git, commit baixado do GitHub, ou data da atualização.
if [ -f "$SRC/.commit" ]; then
    echo "$(date '+%Y.%m.%d') ($(cat "$SRC/.commit"))" >/opt/skystation/VERSION
elif git -c safe.directory='*' -C "$SRC" rev-parse --short HEAD >/dev/null 2>&1; then
    echo "$(git -c safe.directory='*' -C "$SRC" log -1 --format='%cd' --date=format:'%Y.%m.%d') ($(git -c safe.directory='*' -C "$SRC" rev-parse --short HEAD))" >/opt/skystation/VERSION
else
    date '+%Y.%m.%d %H:%M' >/opt/skystation/VERSION
fi

echo "Console atualizado em /opt/skystation ($(cat /opt/skystation/VERSION)). Para ver: logout"
