#!/bin/bash
# SkyStation: sessão do console.
# Abre o compositor kiosk "cage" com um único app em tela cheia (o launcher)
# (via sky-shell, que também sobe o botão Home).

LOG_DIR="$HOME/.local/state/skystation"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/session.log"
[ -f "$LOG" ] && cp -f "$LOG" "$LOG_DIR/session.anterior.log"   # guarda o log da sessão passada
T_INICIO=$(date +%s)

export PATH="/opt/skystation/bin:$PATH"

# Barramento D-Bus do usuário (navegador e apps GTK precisam dele).
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
fi

# wlroots (base do cage) recusa renderização por software por padrão.
export WLR_RENDERER_ALLOW_SOFTWARE=1
# Cursores por hardware falham em várias VMs.
export WLR_NO_HARDWARE_CURSORS=1

# Apps SDL/pygame falam Wayland direto, sem XWayland.
export SDL_VIDEODRIVER=wayland
export XDG_SESSION_TYPE=wayland

# Fase 3+: launcher em Godot (renderizador de compatibilidade, OpenGL 3.3).
# Se o Godot ou o launcher não existirem, cai na tela provisória da Fase 2.
if command -v godot >/dev/null 2>&1 && [ -f /opt/skystation/launcher/project.godot ]; then
    APP="godot --path /opt/skystation/launcher --rendering-driver opengl3"
else
    APP="python3 /opt/skystation/placeholder/main.py"
fi
# Fase 5: o sky-shell sobe o botão Home DENTRO do cage (precisa da tela Wayland para o menu).
[ -x /opt/skystation/bin/sky-shell ] && APP="/opt/skystation/bin/sky-shell $APP"

# Ponte de diagnóstico: alguns segundos após abrir, copia o log para a pasta compartilhada
# da VM (se existir). Assim dá para ler o log mesmo com o console aberto ou travado.
( sleep 10; [ -w /mnt/skystation ] && cp "$LOG" /mnt/skystation/session.log ) 2>/dev/null &

# Modo TV (Fase 6.0): "-m last" = só a última tela conectada. Ligou o HDMI, a imagem vai para a
# TV (a tela do notebook apaga); tirou o cabo, volta para a tela do console. Sem reiniciar nada.
CAGE_OPTS="-m last"
cage -h 2>&1 | grep -q -- "-m extend" || CAGE_OPTS=""

# Modo de vídeo (comando skystation-vm):
#   auto     -> tenta a GPU; se o compositor cair nos primeiros 20 s, usa só CPU (pixman)
#   hibrido  -> compositor na CPU, launcher e jogos na GPU (útil na VM com aceleração 3D)
#   software -> tudo na CPU (o mais compatível, o mais lento)
MODE="$(tr -d '[:space:]' 2>/dev/null <"$HOME/.config/skystation/video")"
case "$MODE" in
    hibrido)
        WLR_RENDERER=pixman cage -s $CAGE_OPTS -- $APP >"$LOG" 2>&1
        code=$?
        ;;
    software)
        WLR_RENDERER=pixman LIBGL_ALWAYS_SOFTWARE=1 cage -s $CAGE_OPTS -- $APP >"$LOG" 2>&1
        code=$?
        ;;
    *)
        # -s permite trocar de tty (Ctrl+Alt+F2) mesmo com o cage aberto.
        t0=$(date +%s)
        WLR_RENDERER=gles2 cage -s $CAGE_OPTS -- $APP >"$LOG" 2>&1
        code=$?
        # Caiu logo no começo (sem GPU utilizável, driver abortou...)? Plano B: tudo na CPU.
        if [ $code -ne 0 ] && [ $(( $(date +%s) - t0 )) -lt 20 ]; then
            echo "--- GPU falhou (código $code): tentando WLR_RENDERER=pixman ---" >>"$LOG"
            WLR_RENDERER=pixman LIBGL_ALWAYS_SOFTWARE=1 cage -s $CAGE_OPTS -- $APP >>"$LOG" 2>&1
            code=$?
        fi
        ;;
esac

# Se a pasta compartilhada da VM existir, deixa uma cópia do log lá (ponte de diagnóstico).
[ -w /mnt/skystation ] && cp "$LOG" /mnt/skystation/session.log 2>/dev/null

# Fase 6.4: o cage às vezes cai (código 139) justamente ao fechar, por exemplo quando o menu se
# reinicia depois de uma atualização. Se a sessão já tinha funcionado por um tempo, isso conta como
# saída normal e o console reabre sozinho, em vez de largar o jogador num terminal. Para não ficar
# reabrindo sem parar, no máximo 3 quedas em 5 minutos.
if [ $code -ne 0 ] && [ $(( $(date +%s) - T_INICIO )) -ge 30 ]; then
    QUEDAS="$LOG_DIR/quedas"
    agora=$(date +%s)
    { cat "$QUEDAS" 2>/dev/null; echo "$agora"; } | awk -v a="$agora" 'a - $1 < 300' >"$QUEDAS.novo"
    mv -f "$QUEDAS.novo" "$QUEDAS"
    if [ "$(wc -l <"$QUEDAS")" -le 3 ]; then
        echo "--- compositor saiu com código $code depois de funcionar: reabrindo ---" >>"$LOG"
        code=0
    fi
fi

exit $code
