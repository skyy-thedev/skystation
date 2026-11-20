#!/bin/bash
# SkyStation: instala o app oficial do GeForce NOW (Fase 11.8). Comando: skystation-nuvem
# Roda como root pelo serviço skystation-nuvem (pedido em /var/lib/skystation/pedidos/geforcenow,
# feito pelo sky-nuvem na primeira vez que o app é aberto, ou pelo skystation-atualizar).
# O app vem do repositório Flatpak da própria NVIDIA (não é o Flathub); o runtime ocupa ~2 GB.
set -u
LOG=/var/log/skystation-instalar.log
PEDIDO=/var/lib/skystation/pedidos/geforcenow
ID=com.nvidia.geforcenow
REPO_URL="https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo"

anota() { echo "[$(date '+%F %T')] nuvem: $*" >>"$LOG"; }
rm -f "$PEDIDO"
[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo."; exit 1; }

if flatpak info "$ID" >/dev/null 2>&1; then
    anota "GeForce NOW já instalado; atualizando"
    timeout 1200 flatpak update -y --noninteractive "$ID" >>"$LOG" 2>&1
    exit 0
fi

livre_gb=$(( $(df --output=avail -k /var/lib 2>/dev/null | tail -1) / 1024 / 1024 ))
if [ "$livre_gb" -lt 4 ]; then
    anota "pouco espaço (${livre_gb} GB livres; precisa de 4): GeForce NOW fica só na versão web"
    exit 1
fi

if ! command -v flatpak >/dev/null 2>&1; then
    anota "instalando o flatpak"
    timeout 600 pacman -S --needed --noconfirm flatpak >>"$LOG" 2>&1 || { anota "falhou o pacman flatpak"; exit 1; }
fi
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$LOG" 2>&1
flatpak remote-add --if-not-exists GeForceNOW "$REPO_URL" >>"$LOG" 2>&1
anota "baixando o GeForce NOW (pode levar vários minutos)"
if timeout 3000 flatpak install -y --noninteractive GeForceNOW "$ID" >>"$LOG" 2>&1; then
    anota "GeForce NOW instalado"
else
    anota "ERRO ao instalar o GeForce NOW (código $?); a versão web continua funcionando"
    exit 1
fi
