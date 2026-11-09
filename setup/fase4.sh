#!/bin/bash
# SkyStation: Fase 4
#   A. Base de desempenho: GameMode, MangoHud, zram, journald na RAM, noatime, serviços enxutos
#   B. Estabilidade: botão Home, sky-run, pastas fixas de saves
#   C. Emuladores: PS1 (RetroArch + PCSX-ReARMed), PS2 (PCSX2), PC antigo (Wine)
#   D. Portabilidade: boot que funciona em qualquer PC (VM, notebook, Ryzen)
# Uso (na VM):  sudo bash /mnt/skystation/setup/fase4.sh
set -euo pipefail

USER_NAME="sky"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
UHOME="/home/$USER_NAME"
step() { echo; echo "==> $*"; }

[ "$(id -u)" -eq 0 ] || { echo "Rode com sudo: sudo bash $0"; exit 1; }

# ------------------------------------------------------------------ pacotes
step "[1/9] Pacotes (desempenho, emulação, drivers Intel e AMD)"
pacman -Syu --needed --noconfirm \
    gamemode mangohud zram-generator python-evdev \
    retroarch wine unzip curl \
    pipewire-pulse \
    mesa vulkan-intel vulkan-radeon libva-intel-driver \
    intel-ucode amd-ucode linux-firmware \
    cloud-guest-utils

usermod -aG gamemode,input,video "$USER_NAME"

# ------------------------------------------------------------------ GameMode
step "[2/9] GameMode: CPU em desempenho máximo só durante o jogo"
cat > /etc/gamemode.ini <<'EOF'
; SkyStation: ativado pelo sky-run a cada jogo (gamemoderun)
[general]
; prioridade extra para o processo do jogo
renice=10
desiredgov=performance
defaultgov=powersave
inhibit_screensaver=0

[custom]
start=logger "SkyStation: GameMode ligado"
end=logger "SkyStation: GameMode desligado"
EOF

# ------------------------------------------------------------------ memória
step "[3/9] zram: swap comprimido na RAM (nada de swap no pendrive/cartão)"
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
cat > /etc/sysctl.d/99-skystation.conf <<'EOF'
# zram é muito mais rápido que disco: o kernel pode usá-lo sem medo
vm.swappiness = 100
vm.page-cluster = 0
EOF
systemctl daemon-reload
systemctl start systemd-zram-setup@zram0.service 2>/dev/null || true

# ------------------------------------------------------------------ escrita mínima
step "[4/9] Menos escrita na mídia: logs do sistema na RAM e noatime"
install -d /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/skystation.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
EOF
# relatime -> noatime nas partições ext4 (não grava "último acesso" a cada leitura)
cp /etc/fstab /etc/fstab.antes-fase4
sed -i -E '/\sext4\s/ s/\brelatime\b/noatime/' /etc/fstab

# ------------------------------------------------------------------ serviços
step "[5/9] Serviços: boot mais rápido, nada rodando à toa"
for svc in NetworkManager-wait-online.service systemd-networkd-wait-online.service \
           ModemManager.service cups.service avahi-daemon.service; do
    if systemctl is-enabled "$svc" >/dev/null 2>&1; then
        systemctl disable "$svc" && echo "   desligado: $svc"
    fi
done
install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation"
systemctl list-unit-files --state=enabled --no-pager > "$UHOME/skystation/servicos-ativos.txt" || true

# ------------------------------------------------------------------ pastas
step "[6/9] Pastas fixas: jogos, ROMs, BIOS, saves, benchmarks"
for d in games roms/ps1 roms/ps2 bios/ps1 bios/ps2 saves/ps1 saves/ps2 states/ps1 states/ps2 wine benchmarks; do
    install -d -o "$USER_NAME" -g "$USER_NAME" "$UHOME/skystation/$d"
done

# ------------------------------------------------------------------ emuladores
step "[7/9] Emuladores"
install -d /opt/skystation/emu/cores
echo "   PS1: core PCSX-ReARMed (buildbot oficial do libretro)"
TMP="$(mktemp -d)"
curl -fsSL -o "$TMP/rearmed.zip" \
    "https://buildbot.libretro.com/nightly/linux/x86_64/latest/pcsx_rearmed_libretro.so.zip"
unzip -o -q "$TMP/rearmed.zip" -d /opt/skystation/emu/cores/

echo "   PS2: PCSX2 (AppImage oficial, extraído: não depende de FUSE)"
if [ ! -x /opt/pcsx2/AppRun ]; then
    URL="$(curl -fsSL https://api.github.com/repos/PCSX2/pcsx2/releases/latest \
        | grep -o '"browser_download_url": *"[^"]*linux-appimage-x64-Qt\.AppImage"' \
        | head -1 | sed 's/.*"\(https[^"]*\)"/\1/' || true)"
    if [ -n "$URL" ]; then
        curl -fsSL -o "$TMP/pcsx2.AppImage" "$URL"
        chmod +x "$TMP/pcsx2.AppImage"
        (cd "$TMP" && ./pcsx2.AppImage --appimage-extract >/dev/null)
        rm -rf /opt/pcsx2 && mv "$TMP/squashfs-root" /opt/pcsx2
        echo "   PCSX2 instalado: $(basename "$URL")"
    else
        echo "   AVISO: não achei o PCSX2 no GitHub agora; rode a fase 4 de novo mais tarde."
    fi
else
    echo "   PCSX2 já instalado."
fi
rm -rf "$TMP"

# ------------------------------------------------------------------ console
step "[8/9] Copiando o console (launcher, bin, configs) para /opt/skystation"
bash "$SRC/setup/atualizar.sh"
install -m 755 "$SRC/setup/expandir.sh" /usr/local/bin/skystation-expandir

# ------------------------------------------------------------------ boot universal
step "[9/9] Boot universal: funciona em qualquer PC, não só nesta VM"
# 1) initramfs genérico: sem o hook "autodetect", a imagem leva drivers de USB, SATA, NVMe e GPUs.
if grep -qE '^HOOKS=.*\bautodetect\b' /etc/mkinitcpio.conf; then
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.antes-fase4
    sed -i -E '/^HOOKS=/ s/ ?\bautodetect\b//' /etc/mkinitcpio.conf
fi
for f in /etc/mkinitcpio.conf.d/*.conf; do
    if [ -f "$f" ] && grep -qE '^HOOKS=.*\bautodetect\b' "$f"; then
        sed -i -E '/^HOOKS=/ s/ ?\bautodetect\b//' "$f"
    fi
done
grep -h '^HOOKS=' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf 2>/dev/null || true
mkinitcpio -P
# 2) bootloader também no caminho padrão EFI/BOOT/BOOTX64.EFI, que todo firmware UEFI procura.
ESP="$(findmnt -n -o TARGET -t vfat | head -1)"
if [ -d /boot/grub ] && [ -n "$ESP" ]; then
    grub-install --target=x86_64-efi --efi-directory="$ESP" --removable --recheck
    grub-mkconfig -o /boot/grub/grub.cfg
elif command -v bootctl >/dev/null 2>&1 && [ -n "$ESP" ]; then
    bootctl install --esp-path="$ESP" || true
else
    echo "   AVISO: não identifiquei o bootloader; me mande o resultado de: findmnt; ls /boot"
fi

echo
echo "Fase 4 instalada."
echo "  - Teste na VM:  sudo reboot"
echo "  - Coloque jogos de PS1 em ~/skystation/roms/ps1 (ou na pasta compartilhada: roms/ps1)"
echo "  - BIOS do PS2 (do seu console) em ~/skystation/bios/ps2"
echo "  - Depois: clonar para o cartão/pendrive (guia em docs/clonar-para-midia.md)"
