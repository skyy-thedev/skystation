#!/bin/bash
# SkyStation: confere se as fases foram aplicadas no console.   Uso:  skystation-verificar   (sem sudo)
H="$HOME"; [ "$(id -u)" -eq 0 ] && H="/home/sky"
ok=0; falhas=0
v() {  # v "descrição" "dica se falhar" comando...
    local d="$1" dica="$2"; shift 2
    if "$@" >/dev/null 2>&1; then echo "  ✓ $d"; ok=$((ok + 1))
    else echo "  ✗ $d"; [ -n "$dica" ] && echo "      → $dica"; falhas=$((falhas + 1)); fi
}
FASE="sudo bash /opt/skystation-src/setup"

echo "== Versão"
inst="$(cat /opt/skystation/VERSION 2>/dev/null)"
echo "  instalada: ${inst:-?}"
ult="$(curl -fsS -m 8 https://api.github.com/repos/skyy-thedev/skystation/commits/main 2>/dev/null \
      | grep -m1 '"sha"' | sed 's/.*"sha": *"\([0-9a-f]\{7\}\).*/\1/')"
if [ -n "$ult" ]; then
    echo "  no GitHub: $ult"
    v "console na última versão" "Sistema → Atualizar o SkyStation" grep -q "$ult" /opt/skystation/VERSION
else
    echo "  (sem internet para comparar com o GitHub)"
fi

echo "== 5.7.2 Atualizar pelo menu (sem sudo)"
v "serviço de atualização ativo" "sudo skystation-atualizar (uma vez)" systemctl is-active --quiet skystation-atualizar.path
v "pasta de pedidos do usuário sky" "sudo skystation-atualizar (uma vez)" test -w /var/lib/skystation/pedidos

echo "== 5.7 / 5.7.1"
v "som de ligar no boot" "$FASE/fase5-7.sh" systemctl is-enabled --quiet skystation-som-ligar.service
v "Central web e mover jogos" "sudo skystation-atualizar" test -x /opt/skystation/bin/sky-receber -a -x /opt/skystation/bin/sky-jogos
v "BIOS do PS2 instalada" "Central web → Enviar → BIOS do PS2" sh -c "find '$H/skystation/bios/ps2' -maxdepth 1 -size 4096k | grep -q ."

echo "== 5.8 Disco no leitor"
v "módulo sg carregado" "$FASE/fase5-8.sh e reinicie" grep -qw '^sg' /proc/modules
v "regra do leitor (udev)" "$FASE/fase5-8.sh" test -f /etc/udev/rules.d/71-skystation-disco.rules
v "acesso ao leitor (sr/sg)" "$FASE/fase5-8.sh e reinicie" sh -c 'for d in /dev/sr[0-9]*; do [ -r "$d" ] || exit 1; done; for s in /sys/class/block/sr*/device/scsi_generic/sg*; do [ -w "/dev/$(basename "$s")" ] || exit 1; done'

echo "== 5.9 Desempenho por jogo (PS2)"
v "ajustes por jogo no PCSX2" "sudo skystation-atualizar" grep -q "ps2-desempenho" /opt/skystation/bin/sky-pcsx2-ini

echo "== 6.0 Modo TV / Central web / Copiar disco"
v "cdrdao (copiar CD de PS1)" "$FASE/fase6-0.sh" command -v cdrdao
v "chdman (compactar CHD)" "$FASE/fase6-0.sh" command -v chdman
v "pactl (som na TV)" "$FASE/fase6-0.sh" command -v pactl
v "cage aceita -m last" "sudo pacman -Syu (cage antigo)" sh -c 'cage -h 2>&1 | grep -q -- "-m extend"'
v "sessão com Modo TV configurada" "sudo skystation-atualizar" grep -q 'CAGE_OPTS="-m last"' /opt/skystation/session.sh
v "Modo TV ativo agora (precisa reiniciar após a 6.0)" "sudo reboot" sh -c 'pgrep -a cage | grep -q -- "-m last"'
v "sons novos (disco, TV)" "sudo skystation-atualizar" test -f /opt/skystation/sounds/tv-on.wav

echo "== 6.1 Favoritos / cópias dos saves / versão anterior"
v "cópia automática dos saves" "Sistema → Atualizar o SkyStation" test -x /opt/skystation/bin/sky-backup
v "pedido de voltar versão aceito" "sudo skystation-atualizar (uma vez)" grep -q reverter /etc/systemd/system/skystation-atualizar.path
v "versão anterior guardada" "aparece depois da próxima atualização" test -f /opt/skystation.anterior/VERSION

echo "== 6.2 QR / teclado pelo celular / terminal / touchpad / SNES e N64"
F62="sudo bash /opt/skystation-src/setup/fase6-2.sh"
v "QR code (python-qrcode)" "$F62" python3 -c "import qrcode"
v "celular como teclado (wtype)" "$F62" command -v wtype
v "terminal (foot)" "$F62" command -v foot
v "emulador de SNES" "$F62" test -f /opt/skystation/emu/cores/snes9x_libretro.so
v "emulador de N64" "$F62" test -f /opt/skystation/emu/cores/mupen64plus_next_libretro.so
v "gestos do touchpad no sky-notify" "Sistema → Atualizar o SkyStation" grep -q touchpad_worker /opt/skystation/bin/sky-notify

echo "== 6.3 Perfis / troféus / YouTube / Moonlight"
F63="sudo bash /opt/skystation-src/setup/fase6-3.sh"
v "perfis e troféus" "Sistema → Atualizar o SkyStation" test -x /opt/skystation/bin/sky-perfis -a -x /opt/skystation/bin/sky-trofeus
v "saves separados por perfil" "abra o menu uma vez depois de atualizar" test -L "$H/skystation/saves"
v "YouTube: WebKit" "sudo skystation-atualizar" python3 -c "import gi; gi.require_version('WebKit','6.0')"
v "YouTube: codecs de vídeo" "$F63" sh -c "pacman -Q gst-libav gst-plugins-good"
v "Moonlight instalado" "$F63" sh -c "command -v moonlight || command -v moonlight-qt || test -x /opt/moonlight/AppRun"

echo "== 6.5 PSP / desempenho automático / conferir cópia"
F65="sudo bash /opt/skystation-src/setup/fase6-5.sh"
v "emulador de PSP" "$F65" test -f /opt/skystation/emu/cores/ppsspp_libretro.so
v "arquivos de apoio do PSP" "$F65" test -d "$H/skystation/bios/psp/PPSSPP"
v "desempenho automático no PS2" "Sistema → Atualizar o SkyStation" grep -q PESADOS /opt/skystation/bin/sky-pcsx2-ini

echo "== 7.0 Central web em segundo plano / som de ligar na TV / PS3"
F70="sudo bash /opt/skystation-src/setup/fase7-0.sh"
v "Central web em segundo plano" "Sistema → Atualizar o SkyStation" grep -q servir /opt/skystation/bin/sky-receber
v "som de ligar sai na TV" "sudo skystation-atualizar" grep -q placa_da_tv /usr/local/bin/skystation-som-ligar
v "emulador de PS3 (RPCS3)" "$F70" test -x /opt/rpcs3/AppRun
v "controles Sony direto no RPCS3" "$F70" test -f /etc/udev/rules.d/72-skystation-controles.rules
v "driver de vídeo AMD (Vulkan)" "$F70" pacman -Q vulkan-radeon
v "boot em qualquer PC (sem autodetect)" "$F70" sh -c "! grep -qE '^HOOKS=.*autodetect' /etc/mkinitcpio.conf"
v "firmware do PS3 (PS3UPDAT.PUP)" "envie pela Central web → Sistema: Firmware do PS3" sh -c "ls $H/skystation/bios/ps3/*.[Pp][Uu][Pp] $H/.config/rpcs3/dev_flash/sys/external/liblv2.sprx 2>/dev/null | grep -q ."
t="$(nproc)"; if [ "$t" -ge 6 ]; then echo "  ✓ este PC tem $t threads: PS3 liberado"; else echo "  · este PC tem $t threads: PS3 só abre em PC com 6+ (normal no notebook antigo)"; fi

echo "== 7.2 Velocidade / erros com código / menu de energia"
v "menu de energia no Home" "Sistema → Atualizar o SkyStation" grep -q HOLD_KILL /opt/skystation/bin/sky-home.py
v "velocidade nas transferências" "Sistema → Atualizar o SkyStation" grep -q "def ritmo" /opt/skystation/bin/sky-jogos

echo "== 7.1 Mais consoles"
F71="sudo bash /opt/skystation-src/setup/fase7-1.sh"
C=/opt/skystation/emu/cores
v "GameCube e Wii" "$F71" test -f $C/dolphin_libretro.so
v "apoio do GameCube/Wii" "$F71" test -d "$H/skystation/bios/dolphin/dolphin-emu/Sys"
v "Nintendo DS" "$F71" sh -c "ls $C/melondsds_libretro.so $C/melonds_libretro.so $C/desmume_libretro.so 2>/dev/null | grep -q ."
v "Nintendo 3DS" "$F71" sh -c "ls $C/azahar_libretro.so $C/citra_libretro.so 2>/dev/null | grep -q ."
v "Game Boy / Color / Advance" "$F71" test -f $C/mgba_libretro.so -a -f $C/gambatte_libretro.so
v "NES e Mega Drive" "$F71" sh -c "ls $C/nestopia_libretro.so $C/fceumm_libretro.so 2>/dev/null | grep -q . && test -f $C/genesis_plus_gx_libretro.so"
v "Xbox 360 (Xenia, experimental)" "$F71" sh -c "ls /opt/xenia/xenia_canary /opt/xenia/xenia-canary /opt/xenia/AppRun 2>/dev/null | grep -q ."

echo
if [ "$falhas" -eq 0 ]; then echo "Tudo certo: $ok de $ok verificações ✓"
else echo "$ok ok, $falhas com problema (veja as dicas →)"; fi
