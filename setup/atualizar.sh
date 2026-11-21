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

# Fase 6.1: guarda a versão que está funcionando antes de trocar (Sistema → Voltar à versão anterior).
if [ -f /opt/skystation/VERSION ]; then
    rm -rf /opt/skystation.anterior
    cp -a /opt/skystation /opt/skystation.anterior
fi
install -d /opt/skystation
cp -r "$SRC/console/." /opt/skystation/
# jogos renomeados: some a pasta antiga (o cp acima não apaga nada)
rm -rf /opt/skystation/games/zona-morta     # virou "deadzone" em 20/nov/2026

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

# Jogos feitos no Godot (ex.: DEADZONE) também gravam o cache .godot/ na própria pasta.
for proj in /opt/skystation/games/*/project.godot; do
    [ -f "$proj" ] || continue
    d="$(dirname "$proj")"
    chown -R "$USER_NAME:$USER_NAME" "$d"
    if command -v godot >/dev/null 2>&1; then
        echo "==> Preparando o cache de $(basename "$d") (Godot --import)"
        sudo -u "$USER_NAME" godot --headless --path "$d" --import >/dev/null 2>&1 || true
    fi
done

# Comandos do sistema (skystation-*) sempre na versão mais nova do projeto.
for pair in skystation-atualizar.sh:skystation-atualizar expandir.sh:skystation-expandir \
            diag.sh:skystation-diag marca.sh:skystation-marca diag-controle.sh:skystation-diag-controle \
            energia.sh:skystation-energia som-ligar.sh:skystation-som-ligar \
            atualizar-menu.sh:skystation-atualizar-menu diag-ps2.sh:skystation-diag-ps2 verificar.sh:skystation-verificar \
            potencia.sh:skystation-potencia skyroms-hd.sh:skystation-skyroms-hd nuvem.sh:skystation-nuvem; do  # (o sky-backup vai junto com console/bin)
    f="$SRC/setup/${pair%%:*}"; [ -f "$f" ] || continue
    sed 's/\r$//' "$f" > "/usr/local/bin/${pair##*:}.new"
    chmod 755 "/usr/local/bin/${pair##*:}.new"
    mv -f "/usr/local/bin/${pair##*:}.new" "/usr/local/bin/${pair##*:}"
done

# Atualizar pelo menu (Fase 5.7.2): o launcher cria /var/lib/skystation/pedidos/atualizar e o
# systemd roda a atualização como root. Sem sudo no menu, então nunca pede senha/permissão.
install -d -m 755 -o "$USER_NAME" -g "$USER_NAME" /var/lib/skystation/pedidos
install -d -m 755 /var/lib/skystation/atualizar
cat >/etc/systemd/system/skystation-atualizar.service <<'UNIT'
[Unit]
Description=SkyStation: atualizar pelo menu do console
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/skystation-atualizar-menu
TimeoutStartSec=20min
UNIT
cat >/etc/systemd/system/skystation-atualizar.path <<'UNIT'
[Unit]
Description=SkyStation: pedido de atualização vindo do menu

[Path]
PathExists=/var/lib/skystation/pedidos/atualizar
PathExists=/var/lib/skystation/pedidos/reverter
Unit=skystation-atualizar.service

[Install]
WantedBy=paths.target
UNIT
# Potência nos jogos (Fase 7.5): o sky-run escreve "jogo"/"normal" em pedidos/potencia.
cat >/etc/systemd/system/skystation-potencia.service <<'UNIT'
[Unit]
Description=SkyStation: potência do processador nos jogos

[Service]
Type=oneshot
ExecStart=/usr/local/bin/skystation-potencia
UNIT
cat >/etc/systemd/system/skystation-potencia.path <<'UNIT'
[Unit]
Description=SkyStation: pedido de potência (jogo/normal)

[Path]
PathExists=/var/lib/skystation/pedidos/potencia
Unit=skystation-potencia.service

[Install]
WantedBy=paths.target
UNIT
# Jogos na nuvem (Fase 11.8): o app do GeForce NOW (~2 GB) é instalado em segundo plano, pedido pelo
# sky-nuvem na primeira abertura (pedidos/geforcenow). Sem travar a atualização nem o menu.
cat >/etc/systemd/system/skystation-nuvem.service <<'UNIT'
[Unit]
Description=SkyStation: instalar o app do GeForce NOW
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Nice=10
ExecStart=/usr/local/bin/skystation-nuvem
TimeoutStartSec=60min
UNIT
cat >/etc/systemd/system/skystation-nuvem.path <<'UNIT'
[Unit]
Description=SkyStation: pedido de instalação do GeForce NOW

[Path]
PathExists=/var/lib/skystation/pedidos/geforcenow
Unit=skystation-nuvem.service

[Install]
WantedBy=paths.target
UNIT
# Bluetooth em qualquer notebook (Fase 8.0.1): adaptador sempre ligado no boot, destravado no rfkill
# (muitos notebooks Ryzen ligam com o Bluetooth "bloqueado") e controles reconectando sozinhos.
if [ -f /etc/bluetooth/main.conf ]; then
    if grep -qE '^#?\s*AutoEnable' /etc/bluetooth/main.conf; then
        sed -i -E 's/^#?\s*AutoEnable\s*=.*/AutoEnable=true/' /etc/bluetooth/main.conf
    else
        printf '\n[Policy]\nAutoEnable=true\n' >>/etc/bluetooth/main.conf
    fi
    sed -i -E 's/^#?\s*FastConnectable\s*=.*/FastConnectable=true/' /etc/bluetooth/main.conf
fi
# Controles "compatíveis" de DS4/DS3 não fazem o pareamento completo; sem isto o BlueZ os recusa.
if [ -f /etc/bluetooth/input.conf ]; then
    if grep -qE '^#?\s*ClassicBondedOnly' /etc/bluetooth/input.conf; then
        sed -i -E 's/^#?\s*ClassicBondedOnly\s*=.*/ClassicBondedOnly=false/' /etc/bluetooth/input.conf
    else
        printf '\n[General]\nClassicBondedOnly=false\n' >>/etc/bluetooth/input.conf
    fi
fi
install -d /etc/systemd/system/bluetooth.service.d
cat >/etc/systemd/system/bluetooth.service.d/skystation.conf <<'UNIT'
[Service]
ExecStartPre=-/usr/bin/rfkill unblock bluetooth
UNIT

# Lenovo IdeaPad (8.1.4): no IdeaPad 3 15ALC6 (Ryzen 5 5500U) os modos de energia da Lenovo
# (o "Desempenho extremo" do Fn+Q, que muda limites de energia e o comportamento do cooler) só
# aparecem no Linux com allow_v4_dytc. Com eles, o skystation-potencia liga "performance" nos jogos
# e volta ao normal no menu. Vale a partir do próximo boot.
if grep -qi lenovo /sys/class/dmi/id/sys_vendor 2>/dev/null && \
   grep -qi ideapad /sys/class/dmi/id/product_version /sys/class/dmi/id/product_family 2>/dev/null; then
    echo "options ideapad_laptop allow_v4_dytc=Y" >/etc/modprobe.d/skystation-ideapad.conf
fi

# Jogos direto do HD/SSD do PC (Fase 7.6): no boot procura uma pasta SKYROMS nos discos do PC
# e a monta em /mnt/skyroms (o mesmo lugar do pendrive SKYROMS).
cat >/etc/systemd/system/skystation-skyroms-hd.service <<'UNIT'
[Unit]
Description=SkyStation: jogos do HD/SSD do PC (pasta SKYROMS)
After=local-fs.target systemd-udevd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/skystation-skyroms-hd
ExecStop=/usr/local/bin/skystation-skyroms-hd parar
TimeoutStartSec=90

[Install]
WantedBy=multi-user.target
UNIT
if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
    systemctl enable skystation-skyroms-hd.service >/dev/null 2>&1 || true
    rfkill unblock bluetooth 2>/dev/null || true
    systemctl enable bluetooth.service >/dev/null 2>&1 || true
    systemctl restart bluetooth.service >/dev/null 2>&1 || true
    systemctl restart skystation-skyroms-hd.service >/dev/null 2>&1 || true
    systemctl enable skystation-potencia.path >/dev/null 2>&1 || true
    systemctl restart skystation-potencia.path >/dev/null 2>&1 || true
    systemctl enable skystation-atualizar.path >/dev/null 2>&1 || true
    systemctl restart skystation-atualizar.path >/dev/null 2>&1 || true
    systemctl enable skystation-nuvem.path >/dev/null 2>&1 || true
    systemctl restart skystation-nuvem.path >/dev/null 2>&1 || true
fi

# 13.4: relógio em dual boot. O Linux grava o relógio da placa-mãe em UTC; o Windows lê o mesmo relógio
# como horário local e fica 3 h adiantado depois de usar o SkyStation (e grava datas erradas nos arquivos:
# os jogos baixados "do futuro" não eram achados pelo sky-instalar). Com Windows no PC, o SkyStation
# passa a usar o relógio da placa em horário local, como o Windows. Sem --adjust-system-clock: a hora
# certa (da internet) é que vai para a placa, não o contrário.
if command -v timedatectl >/dev/null 2>&1 && [ -d /run/systemd/system ] \
   && lsblk -rno FSTYPE 2>/dev/null | grep -qx ntfs; then
    [ "$(timedatectl show -p TimeZone --value 2>/dev/null)" = "UTC" ] && timedatectl set-timezone America/Sao_Paulo 2>/dev/null
    if [ "$(timedatectl show -p LocalRTC --value 2>/dev/null)" != "yes" ]; then
        timedatectl set-local-rtc 1 2>/dev/null && echo "    relógio da placa em horário local (igual ao Windows)"
    fi
    timedatectl set-ntp true 2>/dev/null || true
    # 13.7: o set-local-rtc só grava a hora na placa no instante em que liga; depois disso o systemd não regrava.
    # Em 21/nov a placa seguia em UTC (16:32 às 13:32) e o Windows, 3 h adiantado. Com a hora já acertada pela
    # internet, grava agora a hora local na placa (a cada atualização, se estiver mais de 2 min fora).
    if [ "$(timedatectl show -p LocalRTC --value 2>/dev/null)" = "yes" ] \
       && [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = "yes" ] && command -v hwclock >/dev/null 2>&1; then
        rtc="$(date -u -d "$(cat /sys/class/rtc/rtc0/date 2>/dev/null) $(cat /sys/class/rtc/rtc0/time 2>/dev/null)" +%s 2>/dev/null || echo 0)"
        agora="$(date +%s)"; off="$(( $(date +%z | sed -E 's/^([+-])0?([0-9]+)([0-9]{2})$/\1(\2*3600+\3*60)/') ))"
        dif=$(( rtc - (agora + off) )); dif=${dif#-}
        if [ "$dif" -gt 120 ]; then
            hwclock --systohc --localtime && echo "    relógio da placa acertado para a hora local (estava $((dif / 60)) min fora)"
        fi
    fi
fi

# 13.7: o menu (Godot) às vezes abria desenhando pelo processador (llvmpipe: 12 threads, 300–950% de CPU,
# notebook a 100 °C) logo depois de uma atualização: o login novo ainda não tinha a permissão da placa de vídeo
# (o logind só libera /dev/dri para a sessão "ativa"). No grupo render a permissão é fixa.
getent group render >/dev/null 2>&1 && usermod -aG render "$USER_NAME" 2>/dev/null || true

# 13.5: PS Vita pelo Vita3K oficial. Quem já rodou a Fase 13 mas ficou só com o core do RetroArch (que abortava)
# ganha o programa aqui, sem precisar rodar a fase de novo.
if [ ! -x /opt/vita3k/AppRun ] && { [ -f /opt/skystation/emu/cores/flycast_libretro.so ] || [ -f /opt/skystation/emu/cores/vita3k_libretro.so ]; }; then
    echo "    instalando o Vita3K (PS Vita)…"
    timeout 900 bash "$SRC/setup/fase13.sh" --so-vita || echo "    AVISO: não consegui instalar o Vita3K agora (sem internet?); tenta de novo na próxima atualização."
fi

# 13.11: Wii U pelo Cemu oficial (o core do RetroArch dava Erro E1).
if [ ! -x /opt/cemu/AppRun ] && [ -f /opt/skystation/emu/cores/cemu_libretro.so ]; then
    echo "    instalando o Cemu oficial (Wii U)…"
    timeout 900 bash "$SRC/setup/fase13.sh" --so-cemu || echo "    AVISO: não consegui instalar o Cemu agora; tenta de novo na próxima atualização."
fi

# 13.10: RPCS3 mais novo a cada 7 dias (o fase7-0 só instalava uma vez).
if [ -x /opt/rpcs3/AppRun ] && [ -z "$(find /opt/rpcs3/.skystation-url -mtime -7 2>/dev/null)" ]; then
    timeout 900 bash "$SRC/setup/fase7-0.sh" --atualizar-rpcs3 || echo "    AVISO: RPCS3 não atualizado agora."
fi

# 13.8: extrator de .pkg de PS4 (o sky-instalar usa para transformar o .pkg na pasta que o shadPS4 abre).
if [ -x /opt/shadps4/AppRun ] && [ ! -x /opt/orbis/bin/orbis-pkg-util ]; then
    timeout 1200 bash "$SRC/setup/fase13.sh" --so-pkg || echo "    AVISO: extrator de .pkg não instalado agora; tenta de novo na próxima atualização."
fi

# Fase 13.1: jogos que chegam compactados (.zip/.7z/.rar) são instalados pelo sky-instalar com o 7-Zip
# (que abre RAR/RAR5 também). O pacote se chama "7zip" no Arch atual e "p7zip" nos mais antigos.
if ! command -v 7z >/dev/null 2>&1 && ! command -v 7zz >/dev/null 2>&1; then
    timeout 600 pacman -S --needed --noconfirm 7zip >/dev/null 2>&1 \
        || timeout 600 pacman -S --needed --noconfirm p7zip >/dev/null 2>&1 \
        || echo "    AVISO: não consegui instalar o 7-Zip agora (sem internet?). Jogos compactados ficam para depois."
fi

# Fase 13.2 (sky-security): o SKYROMS não executa nada (noexec). O HD já monta assim pelo
# skystation-skyroms-hd; aqui a regra do pendrive SKYROMS de quem instalou antes ganha o mesmo.
REGRA_ROMS=/etc/udev/rules.d/90-skystation-roms.rules
if [ -f "$REGRA_ROMS" ] && ! grep -q noexec "$REGRA_ROMS"; then
    sed -i 's/--options=/--options=noexec,nosuid,nodev,/' "$REGRA_ROMS"
    udevadm control --reload-rules 2>/dev/null || true
    echo "    sky-security: pendrive SKYROMS passa a montar sem execução (vale ao reconectar)"
fi
# ClamAV: o antivírus que o sky-security usa para conferir os compactados antes de instalar.
# Sem ele, o sky-security ainda bloqueia programas pela lista de extensões. As assinaturas
# (~350 MB em /var/lib/clamav) são atualizadas uma vez por dia, com prioridade baixa.
if ! command -v clamscan >/dev/null 2>&1; then
    timeout 900 pacman -S --needed --noconfirm clamav >/dev/null 2>&1 \
        || echo "    AVISO: não consegui instalar o ClamAV agora (sem internet?). O sky-security fica só com a lista de extensões."
fi
if command -v freshclam >/dev/null 2>&1; then
    cat >/etc/systemd/system/skystation-freshclam.service <<'UNIT'
[Unit]
Description=SkyStation: atualiza as assinaturas do antivírus (sky-security)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/bin/freshclam --quiet
UNIT
    cat >/etc/systemd/system/skystation-freshclam.timer <<'UNIT'
[Unit]
Description=SkyStation: assinaturas do antivírus uma vez por dia

[Timer]
OnBootSec=10min
OnUnitActiveSec=1d
Persistent=true

[Install]
WantedBy=timers.target
UNIT
    if [ -d /run/systemd/system ]; then
        systemctl daemon-reload || true
        systemctl enable --now skystation-freshclam.timer >/dev/null 2>&1 || true
        ls /var/lib/clamav/*.c[lv]d >/dev/null 2>&1 || systemctl start --no-block skystation-freshclam.service 2>/dev/null || true
    fi
fi

# Fase 11.8: Xbox Cloud Gaming roda no Chromium (a Microsoft não tem app do Xbox para Linux);
# o flatpak é para o app oficial do GeForce NOW, que fica para depois (serviço acima).
for p in chromium flatpak; do
    pacman -Q "$p" >/dev/null 2>&1 && continue
    if ! timeout 900 pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then
        echo "    AVISO: não consegui instalar $p agora (sem internet?). Xbox Cloud Gaming/GeForce NOW ficam para a próxima atualização."
    fi
done

# Fase 9.3: avisos por cima do jogo usam o gamescope (o compositor do Steam Deck) e o xprop (marca a
# janela de aviso como overlay); o python-cairo desenha o aviso. Só instala; quem liga é o menu (Sistema → Avisos por cima do jogo).
for p in gamescope xorg-xprop python-cairo; do
    pacman -Q "$p" >/dev/null 2>&1 && continue
    if ! timeout 600 pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then
        echo "    AVISO: não consegui instalar $p agora (sem internet?). Os avisos por cima do jogo ficam desligados."
    fi
done

# Terminal secreto e "Teclar" da Central no gamescope: lá só existe X11, e o foot e o wtype são só Wayland
# (o foot falhava com "failed to connect to wayland", E230). alacritty/xterm = terminal; xdotool = teclar.
for p in alacritty xterm xdotool; do
    pacman -Q "$p" >/dev/null 2>&1 && continue
    if ! timeout 600 pacman -S --needed --noconfirm "$p" >/dev/null 2>&1; then
        echo "    AVISO: não consegui instalar $p agora (sem internet?). Terminal/teclar no gamescope ficam para depois."
    fi
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
