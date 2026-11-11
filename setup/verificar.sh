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

echo
if [ "$falhas" -eq 0 ]; then echo "Tudo certo: $ok de $ok verificações ✓"
else echo "$ok ok, $falhas com problema (veja as dicas →)"; fi
